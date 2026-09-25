---
name: paperclip-plan-to-issue
description: >
  Turn a plan-doc markdown file (docs/plans/*.md) into a proper Paperclip parent
  issue: full plan posted as the issue `plan` document, one sub-issue per
  workstream with parent/child + blocker edges, everything parked in `backlog`.
  Runs from any checkout (home-lab, lies-exposed, …) as the operator, using the board token — not a
  zeroclaw-pod skill. Trigger phrases: "turn this plan into a paperclip issue",
  "convert docs/plans/X.md to a paperclip parent + sub-issues", "file this plan
  on the board in backlog".
---

# paperclip-plan-to-issue

Convert a repo plan document into a Paperclip **parent issue + sub-issues**,
with the whole plan text stored as the parent's `plan` document so agents that
later pick the work up read it in full. The tree lands in **`backlog`** — this
skill files work, it does not schedule it.

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
  and want it tracked on the board as a parent with a decomposed sub-issue list.
- **Don't use** to convert a plan that is *already* a Paperclip issue document
  into executable tasks from inside a heartbeat run — that is the zeroclaw-pod
  skill `services/zeroclaw/skills/coding/paperclip-converting-plans-to-tasks`.
  This skill is the operator-side, cold-start, "get it onto the board" path.

## Prerequisites

- `kubectl` with the `$PAPERCLIP_KUBE_CONTEXT` context, namespace `$PAPERCLIP_NAMESPACE` (Paperclip
  lives there).
- `PAPERCLIP_BOARD_TOKEN` + `PAPERCLIP_COMPANY_ID` in `~/.env` (template: dotfiles `env.example`). If the
  token is expired (`401`), refresh it with the `paperclip-board-token` skill.
- The plan file on disk in the current checkout.

Paperclip is behind Cloudflare Access, so calls go **from inside the paperclip
pod** over localhost (no Access gate):

```bash
set -a; . ~/.env; set +a          # PAPERCLIP_* vars
export CID="$PAPERCLIP_COMPANY_ID"
PC() {  # PC <METHOD> <path>  — body on stdin for POST/PUT
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

- **`backlog` only.** Every issue this skill creates — parent and children — is
  created with `"status": "backlog"`. Do not set `todo`/`in_progress`; the point
  is to park, not schedule. Assigning an agent is fine (backlog does not wake).
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
- **Abstract** — 2–4 sentences: what and why, the key constraint, that it is
  parked in backlog.
- **Workstreams** — the ordered list of sub-issues. A deploy-order / rollout
  section near the end of the plan is usually the best decomposition source.
- **Dependency edges** — which workstream blocks which (e.g. "apply live config"
  is blocked by "ship the chart change").
- **Assignees** — map each workstream to a Paperclip agent by role
  (`GET /api/companies/{CID}/agents` → match `name`/`title`; infra/helm →
  `DevOpsAgent`, live cluster mutation → `SysAdmin`, verification → `QAEngineer`,
  etc.). Leave `assigneeAgentId` off only if no agent fits.

### Step 2 — Resolve project + goal

```bash
PC GET "/api/companies/$CID/projects" # pick the project this plan belongs to
PC GET "/api/companies/$CID/goals"    # pick the goal (often one company goal)
```

Record `projectId` and `goalId` — set both on the parent and every sub-issue.

### Step 3 — Create the parent issue (backlog)

```bash
PC POST "/api/companies/$CID/issues" <<JSON
{
  "title": "<parent title>",
  "status": "backlog",
  "priority": "medium",
  "projectId": "<projectId>",
  "goalId": "<goalId>",
  "description": "<abstract>\n\nFull plan is in the **plan** document on this issue (mirrors \`docs/plans/<name>.md\`). Parked in backlog.\n\nSub-issues:\n1. <title>\n2. <title>\n..."
}
JSON
```

Capture `.id` (uuid) and `.identifier` (`HOM-NN`) from the response.

### Step 4 — Post the plan as the `plan` document

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

### Step 5 — Create the sub-issues (backlog, parented, blocked)

For each workstream, in dependency order so blocker ids exist when referenced:

```bash
PC POST "/api/companies/$CID/issues" <<JSON
{
  "title": "<workstream title>",
  "status": "backlog",
  "priority": "medium",
  "parentId": "<parent-id>",
  "projectId": "<projectId>",
  "goalId": "<goalId>",
  "assigneeAgentId": "<agent-id or omit>",
  "blockedByIssueIds": ["<blocker-sub-id>", "..."],
  "description": "<what this delivers>\n\n**Scope**\n- ...\n\n**Acceptance**\n- ...\n\nSee the plan document on the parent (HOM-NN) §<n>."
}
JSON
```

`blockedByIssueIds` **replaces** the set on each write; omit it for
no-dependency issues. Circular / self edges are rejected.

### Step 6 — Verify

```bash
PC GET "/api/companies/$CID/issues?parentId=<parent-id>"   # all children, all backlog
PC GET "/api/issues/<each-blocked-sub-id>"                  # blockedBy shows the right identifiers
PC GET "/api/issues/<parent-id>/documents/plan"            # body length ~= plan file size
```

### Step 7 — Report

Give the user the parent identifier and the sub-issue list with their blocker
edges and assignees, e.g.:

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
- Issue creation with `"status": "backlog"` is accepted directly; no create-then-
  PATCH dance is needed.
- The `GET /api/issues/{id}` response does not embed `children` or `documents` —
  list children with `?parentId=`, fetch the plan via the documents endpoint.
- Keep the repo plan doc as the working copy; the Paperclip `plan` document is a
  point-in-time mirror. If the plan changes materially before the work starts,
  re-`PUT` the document with the current `baseRevisionId`.
