---
name: paperclip-plan-to-issue
description: >
  Turn a plan-doc markdown file (docs/plans/*.md) into a proper Paperclip parent
  issue: full plan posted as the issue `plan` document, one sub-issue per
  workstream with parent/child + blocker edges. By default the parent goes to
  `todo` assigned to an owner agent, whose direct reports get the sub-issues;
  `--backlog` parks the whole tree instead.
  Runs from any checkout (home-lab, lies-exposed, …) as the operator, using the board token — not a
  zeroclaw-pod skill. Trigger phrases: "turn this plan into a paperclip issue",
  "convert docs/plans/X.md to a paperclip parent + sub-issues", "hand this plan
  to <agent>", "file this plan on the board in backlog" (→ `--backlog`).
---

# paperclip-plan-to-issue

Convert a repo plan document into a Paperclip **parent issue + sub-issues**,
with the whole plan text stored as the parent's `plan` document so agents that
later pick the work up read it in full.

**Default mode:** the parent lands in **`todo`, assigned to an owner agent**,
and the sub-issues land in **`todo`, unassigned**, with blocker edges. The owner
reads the plan and assigns each sub-issue to one of its direct reports (agents
whose `reportsTo` is the owner) on its next run or supervision wake.

**`--backlog`** (opt-in, the old behaviour): the whole tree is parked in
`backlog` with role-matched assignees, and nothing runs until someone promotes
it.

Runs from **any checkout** (home-lab, lies-exposed, …) — the skill lives in user
space. Paperclip creds and endpoints come from `~/.env` (template: dotfiles
`env.example`).
Runs as the orchestrator or a
sub-agent, over the **operator board-token** path — the same credential
`paperclip-debug-run` and `services/zeroclaw/scripts/sync/paperclip-instructions.sh`
use. It is **not** a zeroclaw-pod skill; the pod holds no standing Paperclip
credential.

## When to use / not use

- **Use** when you have a finished plan in `docs/plans/<name>.md` (or equivalent)
  and want it on the board as a parent with a decomposed sub-issue list, either
  handed to an owner (default) or parked (`--backlog`).
- **Don't use** to convert a plan that is *already* a Paperclip issue document
  into executable tasks from inside a heartbeat run — that is the zeroclaw-pod
  skill `services/zeroclaw/skills/coding/paperclip-converting-plans-to-tasks`.
  This skill is the operator-side, cold-start, "get it onto the board" path.

## Arguments

- `--owner <agent name>`: the agent that owns the plan (default mode). If not
  given, use `PAPERCLIP_PLAN_OWNER_AGENT` from `~/.env`. If that is not set
  either, use the root agent (`reportsTo: null`).
- `--backlog`: park everything in `backlog` and assign sub-issues by role.
  `--owner` is ignored.

## Prerequisites

- `kubectl` with the `$PAPERCLIP_KUBE_CONTEXT` context, namespace `$PAPERCLIP_NAMESPACE` (Paperclip
  lives there).
- `PAPERCLIP_BOARD_TOKEN` + `PAPERCLIP_COMPANY_ID` in `~/.env` (template: dotfiles `env.example`). If the
  token is expired (`401`), refresh it with the `paperclip-board-token` skill.
- Optional `PAPERCLIP_PLAN_OWNER_AGENT` in `~/.env`: the default owner agent
  name.
- The plan file on disk in the current checkout.

Paperclip is behind Cloudflare Access, so calls go **from inside the paperclip
pod** over localhost (no Access gate):

```bash
set -a; . ~/.env; set +a          # PAPERCLIP_* vars
export CID="$PAPERCLIP_COMPANY_ID"
PC() {  # PC <METHOD> <path>  — body on stdin for POST/PUT/PATCH
  kubectl --context "$PAPERCLIP_KUBE_CONTEXT" -n "$PAPERCLIP_NAMESPACE" exec -i deploy/paperclip -- \
    curl -s -X "$1" -H "Authorization: Bearer $PAPERCLIP_BOARD_TOKEN" \
    -H "Content-Type: application/json" --data-binary @- "http://localhost:3100$2"
}
```

`kubectl exec` prints a `Defaulted container "paperclip" out of: …` line on
stderr — harmless, ignore it; stdout is clean JSON.

Never echo the token, never paste it (or any fetched secret) into an issue,
comment, document, or commit.

## Guardrails

- **Status by mode.** Default: parent `todo`, assigned to the owner; children
  `todo` and **unassigned**. The owner delegates, so do not pick assignees for
  the children yourself. `--backlog`: parent and children all `backlog`,
  children assigned by role (backlog does not wake). Never create anything
  `in_progress`.
- **One owner, resolved once.** Stop and ask the user if the owner name matches
  no agent or more than one, or if there is no single root agent. Warn if the
  owner has no direct reports: it would have to do every sub-issue itself.
- **The owner wakes last.** Assigning a `todo` issue to an agent wakes it. In
  default mode, create the parent in `backlog` with the owner already assigned,
  attach the plan and the children, and flip the parent to `todo` as the final
  write. The owner then wakes to a complete tree.
- **Plan goes in the `plan` document, not the description.** The description is a
  short abstract + the sub-issue list. The verbatim plan body is `PUT` to
  `/api/issues/{id}/documents/plan`.
- **One sub-issue per real workstream.** Decompose to depth 1 (major
  workstreams). Only split finer when a workstream is too big for one agent /
  one PR. Do not mechanically mirror every `##` heading.
- **Dependencies are first-class.** Use `blockedByIssueIds`, not prose "blocked
  by X" — dependents auto-wake when blockers reach `done`.
- **Point at the plan, don't re-transcribe it.** Each sub-issue description
  references the relevant plan section (`See the plan document on the parent
  (HOM-NN) §4`) plus its own acceptance criteria — it does not copy the section.
- **Repo-change rule still applies.** If you also touch repo files (e.g. moving
  the plan doc, adding this skill), that goes on a branch + PR — never pushed to
  `main`. Creating the Paperclip issues themselves is not a repo change.
- **Ticket references are links** in any description/comment body you write:
  `[HOM-53](/HOM/issues/HOM-53)` (derive the `HOM` prefix from the returned
  `identifier`).

## Procedure

### Step 1 — Read the plan, decide the decomposition

Read the whole plan file. Identify:

- **Parent title** — the plan's goal in a few words.
- **Abstract** — 2–4 sentences: what and why, and the key constraint.
- **Workstreams** — the ordered list of sub-issues. A deploy-order / rollout
  section near the end of the plan is usually the best decomposition source.
- **Dependency edges** — which workstream blocks which (e.g. "apply live config"
  is blocked by "ship the chart change").
- **Assignees** — default mode: only the parent, to the owner (Step 2).
  `--backlog` only: map each workstream to a Paperclip agent by role
  (`GET /api/companies/{CID}/agents` → match `name`/`title`; infra/helm →
  `DevOpsAgent`, live cluster mutation → `SysAdmin`, verification → `QAEngineer`,
  etc.). Leave `assigneeAgentId` off only if no agent fits.

### Step 2 — Resolve the owner (default mode only)

`OWNER` is the `--owner` value the user gave, if any.

```bash
PC GET "/api/companies/$CID/agents" < /dev/null > /tmp/agents.json
python3 - "${OWNER:-${PAPERCLIP_PLAN_OWNER_AGENT:-}}" <<'PY'
import json, sys
want = sys.argv[1]
data = json.load(open("/tmp/agents.json"))
agents = [a for a in (data if isinstance(data, list) else data.get("agents", []))
          if a.get("status") not in ("paused", "terminated")]
pick = ([a for a in agents if a["name"].lower() == want.lower()] if want
        else [a for a in agents if not a.get("reportsTo")])
if len(pick) != 1:
    sys.exit(f"owner not resolved: {len(pick)} match(es) for {want or 'root agent'}")
owner = pick[0]
reports = [a["name"] for a in agents if a.get("reportsTo") == owner["id"]]
print(owner["id"], owner["name"], "| reports:", ", ".join(reports) or "NONE")
PY
```

Record the owner id and name.

### Step 3 — Resolve project + goal

```bash
PC GET "/api/companies/$CID/projects" < /dev/null # pick the project this plan belongs to
PC GET "/api/companies/$CID/goals" < /dev/null    # pick the goal (often one company goal)
```

Record `projectId` and `goalId` — set both on the parent and every sub-issue.

### Step 4 — Create the parent issue

Always created in `backlog` first. In default mode the owner is assigned now
and the status flips to `todo` in Step 7.

```bash
PC POST "/api/companies/$CID/issues" <<JSON
{
  "title": "<parent title>",
  "status": "backlog",
  "priority": "medium",
  "assigneeAgentId": "<owner-id>",
  "projectId": "<projectId>",
  "goalId": "<goalId>",
  "description": "<abstract>\n\nFull plan is in the **plan** document on this issue (mirrors \`docs/plans/<name>.md\`).\n\nOwner: assign each sub-issue below to one of your direct reports and supervise it to done.\n\nSub-issues:\n1. <title>\n2. <title>\n..."
}
JSON
```

`--backlog`: omit `assigneeAgentId` and replace the "Owner:" line with
"Parked in backlog."

Capture `.id` (uuid) and `.identifier` (`HOM-NN`) from the response.

### Step 5 — Post the plan as the `plan` document

Build the payload from the file so markdown/newlines round-trip cleanly — do not
hand-escape:

```bash
python3 - "$PLAN_FILE" > /tmp/plan-doc.json <<'PY'
import json, sys
body = open(sys.argv[1]).read()
json.dump({"title": "Plan", "format": "markdown", "body": body, "baseRevisionId": None}, sys.stdout)
PY
PC PUT "/api/issues/<parent-id>/documents/plan" < /tmp/plan-doc.json
```

Response returns `latestRevisionNumber: 1`. If a `plan` doc already exists,
`GET /api/issues/<id>/documents/plan` first and pass its `latestRevisionId` as
`baseRevisionId`.

### Step 6 — Create the sub-issues (parented, blocked)

For each workstream, in dependency order so blocker ids exist when referenced:

```bash
PC POST "/api/companies/$CID/issues" <<JSON
{
  "title": "<workstream title>",
  "status": "todo",
  "priority": "medium",
  "parentId": "<parent-id>",
  "projectId": "<projectId>",
  "goalId": "<goalId>",
  "blockedByIssueIds": ["<blocker-sub-id>", "..."],
  "description": "<what this delivers>\n\n**Scope**\n- ...\n\n**Acceptance**\n- ...\n\nSee the plan document on the parent (HOM-NN) §<n>."
}
JSON
```

Default mode: no `assigneeAgentId`; the owner assigns. An unassigned `todo`
issue wakes nobody, and once the owner assigns it, its blockers still hold it
until they reach `done`.

`--backlog`: `"status": "backlog"` and `"assigneeAgentId": "<agent-id or omit>"`.

`blockedByIssueIds` **replaces** the set on each write; omit it for
no-dependency issues. Circular / self edges are rejected.

### Step 7 — Hand the parent to the owner (default mode only)

The last write. It wakes the owner:

```bash
echo '{"status": "todo"}' | PC PATCH "/api/issues/<parent-id>"
```

### Step 8 — Verify

```bash
PC GET "/api/issues/<parent-id>" < /dev/null                # todo + owner (backlog with --backlog)
PC GET "/api/companies/$CID/issues?parentId=<parent-id>" < /dev/null   # children: todo + unassigned (backlog + assignees with --backlog)
PC GET "/api/issues/<each-blocked-sub-id>" < /dev/null      # blockedBy shows the right identifiers
PC GET "/api/issues/<parent-id>/documents/plan" < /dev/null # body length ~= plan file size
```

### Step 9 — Report

Give the user the parent identifier, its status and owner, and the sub-issue
list with blocker edges (plus assignees in `--backlog` mode), e.g.:

```
HOM-53  CodeGraph for zeroclaw coding agents   (todo → CTO, plan doc rev 1)
├─ HOM-54  Helm: install-codegraph initContainer …        unassigned
├─ HOM-55  Agent bundles: index-bootstrap instructions …  unassigned
├─ HOM-56  config.toml: register codegraph MCP server …   unassigned ← blocked by HOM-54, HOM-55
└─ HOM-57  Smoke test + context update …                  unassigned ← blocked by HOM-56
```

`--backlog`:

```
HOM-53  CodeGraph for zeroclaw coding agents   (backlog, plan doc rev 1)
├─ HOM-54  Helm: install-codegraph initContainer …        DevOpsAgent
├─ HOM-55  Agent bundles: index-bootstrap instructions …  DevOpsAgent
├─ HOM-56  config.toml: register codegraph MCP server …   SysAdmin   ← blocked by HOM-54, HOM-55
└─ HOM-57  Smoke test + context update …                  DevOpsAgent ← blocked by HOM-56
```

## Notes

- The board token is company-scoped. A `403` on an endpoint means the token
  lacks that scope — fall back or refresh via `paperclip-board-token`.
- Issue creation with `"status": "backlog"` or `"todo"` is accepted directly.
- The `GET /api/issues/{id}` response does not embed `children` or `documents` —
  list children with `?parentId=`, fetch the plan via the documents endpoint.
- Keep the repo plan doc as the working copy; the Paperclip `plan` document is a
  point-in-time mirror. If the plan changes materially before the work starts,
  re-`PUT` the document with the current `baseRevisionId`.
