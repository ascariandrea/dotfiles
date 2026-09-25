---
name: paperclip-debug-run
description: >
  Debug a failed or misbehaving Paperclip run that executed on a zeroclaw agent,
  from any checkout. Gathers the Paperclip-side signal (issue thread,
  failure summary, heartbeat-context) and the zeroclaw pod-side signal (adapter
  + agent container logs, CLI session state), classifies the failure, and
  proposes a gated fix to the agent instruction bundle, a live agent prompt, or
  config.toml. Read-only by default — never applies a fix or posts to the issue
  without approval. Trigger phrases: "debug this paperclip run", "why did the
  paperclip agent fail on PAP-123", "the zeroclaw agent botched this run",
  "inspect a paperclip run and fix the agent config".
---

# paperclip-debug-run

Post-mortem a Paperclip run that ran through the zeroclaw HTTP adapter and either
failed, timed out, or did the wrong thing — then decide whether the fix belongs
in the **agent instructions** or in **`config.toml`**, and produce the concrete,
review-gated change.

Runs from **any checkout** (home-lab, lies-exposed, …) — the skill lives in user
space. Paperclip creds and endpoints come from `~/.env` (template: dotfiles
`env.example`).
Runs as the orchestrator or a
sub-agent. It needs:

- `kubectl` with the `$PAPERCLIP_KUBE_CONTEXT` context, namespace `$PAPERCLIP_NAMESPACE` (both
  Paperclip and zeroclaw live there).
- `PAPERCLIP_BOARD_TOKEN` + `PAPERCLIP_COMPANY_ID` in `~/.env` (template: dotfiles `env.example`) (same creds
  `services/zeroclaw/scripts/sync/paperclip-instructions.sh` uses).
- `gh` for opening the fix PR.

It is **not** a zeroclaw-pod skill. The zeroclaw ServiceAccount
(`infrastructure/helm/workstation/charts/zeroclaw/templates/zeroclaw.yaml`,
`zeroclaw-exec` Role) can read `pods`, `pods/log` and `events` in ns `local`
and `create` `pods/exec` — but **no write verbs and no cross-namespace read**,
and by default the pod holds no standing Paperclip credential (only a per-run
JWT during a heartbeat). The cross-issue board signal is only reachable from a
box with cluster access + the board token — i.e. here. (The
`self-improving-reflection-loop` plan automates the in-pod half of this; until
that ships, run it here.)

## Hard limits — read before starting

- **No run API.** `services/zeroclaw/skills/coding/paperclip/references/api-reference.md`
  is explicit: there is no `GET /api/runs/:runId`. Anchor everything on the
  **issue**. The run transcript exists only in the Paperclip UI
  (`/<prefix>/agents/<key>/runs/<run-id>`), not over the API.
- **Pod logs are ephemeral.** `kubectl logs` only covers the current pod since
  its last restart, rotated. If the run is more than a few hours old or the pod
  restarted since, the adapter/agent-side detail is gone — say so in the report,
  do not infer tool-call detail you cannot see.
- **`config.toml` is CLI-only.** Never hand-edit it, never `kubectl cp` it, even
  to match the git snapshot — see `[[feedback-zeroclaw-config-toml-readonly]]`.
  Changes go through `zeroclaw config patch` only.
- **Every repo change is a PR.** Never push to main. Bundle/prompt edits ship on
  a branch + PR; `config patch` and live PVC patches need explicit user approval
  before you run them.
- **Read-only until approved.** Do not post a diagnosis comment on the Paperclip
  issue and do not apply any fix until the user OKs the proposed change.

## Step 0 — Inputs

You need the **Paperclip issue identifier** (e.g. `PAP-123`) or its issue id.
Optional: a `PAPERCLIP_RUN_ID` (`run-…`) from the UI to narrow the log grep, and
an approximate time of the run for `--since`.

```bash
set -a; . ~/.env; set +a          # PAPERCLIP_BOARD_TOKEN, PAPERCLIP_COMPANY_ID
KX="kubectl --context "$PAPERCLIP_KUBE_CONTEXT" -n "$PAPERCLIP_NAMESPACE""
PC() { $KX exec -i deploy/paperclip -- curl -s \
  -H "Authorization: Bearer $PAPERCLIP_BOARD_TOKEN" \
  "http://localhost:3100$1"; }
```

`PC` runs the API call from inside the paperclip pod (localhost, no Cloudflare
Access gate). The board token is company-scoped read; if an endpoint 403s it,
fall back to what the issue thread already shows.

## Step 1 — Paperclip-side signal

```bash
# Resolve the issue id from the identifier if needed:
PC "/api/companies/$PAPERCLIP_COMPANY_ID/issues?q=PAP-123" | jq '.[] | {id,identifier,title,status}'

ISSUE=<issue-id>
PC "/api/issues/$ISSUE"                      | jq '{identifier,title,status,assigneeAgentId,executionState}'
PC "/api/issues/$ISSUE/heartbeat-context"    | jq .
PC "/api/issues/$ISSUE/comments?order=asc"   | jq '.[] | {id, author: (.authorAgentId // .authorUserId), createdAt, body}'
PC "/api/issues/$ISSUE/documents"            | jq '.[] | {key,title,updatedAt}'
```

What to pull out:

- The **failure-summary comment** — the adapter (PR #99) strips ANSI, collapses
  zeroclaw log envelopes, and puts the real error there. This is usually the
  single most useful line.
- Final `status` and `executionState` — a run that ended `in_progress` with no
  scheduled monitor, or bounced off the disposition guard
  (`invalid_issue_disposition` / `in_review_without_action_path`), is a
  **prompt** problem, not an infra one.
- The `assigneeAgentId` → the Paperclip agent. Get its zeroclaw alias:

```bash
PC "/api/companies/$PAPERCLIP_COMPANY_ID/agents" \
  | jq '.[] | select(.id=="<assigneeAgentId>") | {name, adapterType, model: .adapterConfig.model}'
```

`adapterConfig.model` is the picked zeroclaw agent id (`coder`, `researcher`, …).
That, plus the agent `name`, gives you both fix targets: the **overlay slug**
(name → lowercase, non-alphanumeric runs → `-`) and the **live agent** dir.

## Step 2 — Which adapter path ran it

- **Issue-backed run** (a real Paperclip task): the heartbeat hit the adapter
  **plugin** code inside the paperclip pod, which calls the **adapter service**
  in the zeroclaw pod (`:3101`). `body.model` = `adapterConfig.model`.
- **Model-less run** (cron / webhook / routine with no backing agent): no
  `body.model`; the adapter service falls back to `ZEROCLAW_DEFAULT_AGENT`
  (helm `zeroclawHttpAdapter.defaultAgent`, default `coder`). If the run failed
  with a `zeroclaw agent -a <alias>` hard error, the alias is wrong — check it
  against the `[agents.<id>]` blocks in `config.toml` (Step 3).

## Step 3 — zeroclaw pod-side signal

Both containers of the zeroclaw pod. Widen `--since` to comfortably cover the
run; add `--previous` if the pod restarted since.

```bash
$KX logs -l app=zeroclaw-zeroclaw -c http-adapter --since=3h --timestamps \
  | grep -E 'run-[0-9a-f]|'"$ISSUE"'|\[Paperclip\]|\[Zeroclaw\]|Adapter run'
$KX logs -l app=zeroclaw-zeroclaw -c zeroclaw     --since=3h --timestamps \
  | grep -E "$ISSUE|error|panic|WARN|tool call|context"
```

Look for: `[Paperclip] Zeroclaw agent "<x>" (from model|default)`, the deadline
(`ADAPTER_TIMEOUT_MS` / `ADAPTER_IDLE_TIMEOUT_MS`), `Adapter run error|timeout`,
malformed tool-call parse errors, LocalAI `503` / `queue_timeout`, context-token
overflow, provider retries.

CLI session state (keyed by issue + agent) — optional, only if the logs are thin:

```bash
$KX exec deploy/zeroclaw-zeroclaw -c zeroclaw -- \
  find /zeroclaw-data/workspace/.zeroclaw -maxdepth 6 -name "*$ISSUE*" 2>/dev/null
```

Config sanity when the failure looks config-shaped:

```bash
$KX exec deploy/zeroclaw-zeroclaw -c zeroclaw -- zeroclaw config show   # or: cat the config, read-only
```

Confirm the alias from Step 1/2 has a real `[agents.<id>]` block, and check the
knob the symptom points at (see the table below).

## Step 4 — Cross-reference known failure modes

Before writing a fix, check whether this is already a known pattern:

- `context/debugging/playbooks.jsonl` (repo) — grep for `paperclip` / `zeroclaw`.
- mem0 (`homelab-zeroclaw`, `homelab-orchestrator`) if wired in this session.
- The memory index — several of these are already documented (see the table).

## Step 5 — Classify → fix target

| Symptom in the run | Likely cause | Fix target |
| --- | --- | --- |
| Agent asked a human / escalated / sent a Telegram DM when stuck | weak model calling `ask_user`/`escalate_to_human`; missing filter | **C** — `risk_profiles.coder.excluded_tools` (`[[zeroclaw-coder-telegram-push-on-paperclip-runs]]`) |
| Ran `git` in the wrong repo / wrong directory | prompt gap | **A** — `_common.md` "Which repo am I working in?" (HOM-38) |
| Concurrent runs corrupted each other's working tree | prompt gap | **A** — `agents/<slug>.md` (pattern: `fullstackengineer.md`, git-worktree isolation) |
| Malformed `shell({approved:true})` / unparseable XML tool calls | `providers.models.custom.<m>.native_tools = false` for a weak model | **C** + rollout restart (`[[zeroclaw-coder-malformed-tool-calls]]`) |
| PR title/body wrong, or not rebased onto `origin/main` | prompt gap | **B** — `task-to-pr` skill + coder mirror (`[[zeroclaw-coder-github-tool-flailing]]`) |
| Ended with only a text answer, no final `PATCH` (invalid disposition) | prompt gap | **A** — `_common.md` "Ending a run" |
| Cron/webhook run died silently, no crash, no log | noisy tool output exceeded `max_context_tokens` | **C** — tail-truncate the command; `[[zeroclaw-cron-context-overflow]]` |
| Run died at ~5 min, `undici` / `headersTimeout` | infra (adapter fetch) | **D** — `[[paperclip-zeroclaw-5min-undici-headerstimeout]]` |
| `503 queue_timeout` bursts, recovery-run storm | infra (gateway `max_queue_wait_ms`) | **D** — `[[localai-gateway-queue-timeout-stampede]]` |
| opencode empty reply / OOM after a 2nd model loaded | infra (gateway eviction) | **D** — `[[localai-gateway-capacity-reconcile-oom]]` |
| `zeroclaw agent -a <alias>` hard error | bad `adapterConfig.model`, or bad `ZEROCLAW_DEFAULT_AGENT` | check the Paperclip agent's model / helm `defaultAgent` vs `config.toml` |

**Pick the narrowest target.** Many Paperclip agents map to one zeroclaw agent
(e.g. `coder` serves Chief of staff, FullStackEngineer, Reflection Coach …). A
`_common.md` or `config.toml` change hits **all** of them; an `agents/<slug>.md`
overlay hits one.

## Step 6 — Produce the fix (gated)

All fix paths below (`infrastructure/…`, `services/zeroclaw/…`) live in the
**home-lab** repo — `cd "$HOMELAB"` (from `~/.env`) first, even if
the debugged run came from another repo (e.g. lies-exposed).

### A — Agent instruction bundle (repo → Paperclip, PR-gated)

Source: `infrastructure/zeroclaw/paperclip/`.

- Shared execution rule that every agent should follow → edit `_common.md`.
- One Paperclip agent's role / business context / decision boundary → edit
  `agents/<slug>.md` (create it if absent; keep it **repo-agnostic** — no repo
  name, path, or checkout; see `agents/README.md`).

```bash
git checkout -b paperclip-fix-<short> origin/main
$EDITOR infrastructure/zeroclaw/paperclip/agents/<slug>.md
git commit -m "fix(zeroclaw): <agent> overlay — <what and why>"
gh pr create ...
# AFTER MERGE:
services/zeroclaw/scripts/sync/paperclip-instructions.sh --dry-run
services/zeroclaw/scripts/sync/paperclip-instructions.sh --agent "<Paperclip agent name>"
```

Never edit the bundle directly in the Paperclip UI — the next sync overwrites it.

### B — zeroclaw agent prompt (repo is source of truth)

The full agent prompt files live at `services/zeroclaw/agents/<agent>/*.md`.
Edit them there on a branch + PR, then after merge push to the pod:

```bash
services/zeroclaw/scripts/sync/agents-to-pod.sh <agent>
```

`agents-to-pod.sh` kubectl-cps every `*.md` onto the PVC
`…/.zeroclaw/agents/<agent>/workspace/`; non-destructive
(`[[zeroclaw-agents-md-is-pod-to-repo-mirror]]`).

Execution logic that must land on the pod *before* the PR merges — one
idempotent line:

```bash
services/zeroclaw/scripts/sync/agent-line-to-pod.sh <agent> AGENTS.md '<one idempotent line>'
```

It no-ops if the line is already present. Make the same edit in the repo file so
the next `agents-to-pod.sh` run keeps it.

### C — config.toml (CLI only, user-approved)

```bash
$KX exec deploy/zeroclaw-zeroclaw -c zeroclaw -- zeroclaw config patch '<patch expr>'
```

- Never hand-edit `config.toml` or `kubectl cp` it — CLI patch is the only path
  (`[[feedback-zeroclaw-config-toml-readonly]]`).
- `config patch` rejects `remove` on required-with-default fields and any
  non-schema path; use a leaf `replace` to the default instead
  (`[[zeroclaw-config-patch-schema-validation]]`).
- Some knobs (e.g. `native_tools`) have **no hot reload** — follow with
  `kubectl rollout restart deploy/zeroclaw-zeroclaw` (`[[zeroclaw-coder-malformed-tool-calls]]`).
- Get explicit user approval on the exact patch expression before running it.
- The git snapshot of `config.toml` will drift; that is expected — do **not**
  edit the file to catch it up.

### D — Infra (out of scope here)

Adapter timeouts, OOM, gateway 503s, `undici` — report the diagnosis and point
at the relevant memory / helm value. Do not patch instructions or config for
these; file / update an infra issue instead.

## Step 7 — Findings report

Hand the user this, and stop:

```markdown
## Paperclip run debug — <issue-identifier>

**Run:** <run-id | n/a> · **Zeroclaw agent:** <alias> · **Paperclip agent:** <name>
**Adapter path:** issue-backed | model-less(cron/webhook)
**Outcome:** failed | errored | timeout | completed-wrong · **When:** <ts>
**Pod logs:** available | rotated (pod restarted since)

### What happened
<3–6 lines; quote the real error from the failure-summary comment / stderr,
bearer tokens redacted>

### Root cause
<one paragraph>

### Proposed fix
- **Target:** _common.md | agents/<slug>.md | live prompt (<agent>) | config.toml | infra
- **Change:** <concrete diff, or the exact `zeroclaw config patch` expression>
- **Rollout:** PR + sync/paperclip-instructions.sh
           | sync/agent-line-to-pod.sh + pod→repo PR
           | zeroclaw config patch (+ rollout restart?)
           | infra issue
- **Blast radius:** one agent (overlay) | all zeroclaw-adapter agents (_common/config)
- **Hot-reload:** yes | no (needs rollout restart)

### Follow-up / not fixed
<anything left>
```

## Guardrails

- **Secrets.** `$PAPERCLIP_BOARD_TOKEN` and any per-run `PAPERCLIP_API_KEY` /
  bearer token visible in logs — never echo them into the report, a commit, a
  PR, or an issue comment. Redact `Authorization: Bearer …` from every log
  excerpt you quote.
- **Read-only.** No fix is applied and nothing is posted to the Paperclip issue
  until the user approves the proposed change.
- **Ephemeral logs.** No log hits in the `--since` window + a restarted pod =
  "pod-side logs rotated". Do not fabricate tool-call detail.
- **`config.toml` is CLI-only.** No hand edits, no `kubectl cp`, ever.
- **One PR per change**, off `origin/main`, never pushed to main.
- **One run at a time.**
- **Narrowest target wins** — prefer `agents/<slug>.md` over `_common.md` /
  `config.toml` when the fault is one agent's.
