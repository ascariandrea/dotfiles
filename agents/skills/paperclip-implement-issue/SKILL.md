---
name: paperclip-implement-issue
description: >
  Implement a Paperclip board issue by its identifier (e.g. HOM-12) from any
  checkout (home-lab, lies-exposed, …), as the operator: pull the issue + its plan/acceptance
  context off the board, check it out to `in_progress`, do the work on a branch,
  open a PR, and park the issue in `in_review` pointing at that PR. Runs over the
  operator board-token path — not a zeroclaw-pod skill. Trigger phrases:
  "implement HOM-12", "pick up HOM-45 and implement it", "do paperclip issue
  HOM-30", "work the board issue HOM-7".
---

# paperclip-implement-issue

Take a single Paperclip issue named by its **identifier** (`HOM-NN`) and carry it
to a PR from **this checkout**, by hand, as the operator — the human-in-the-loop
alternative to handing the issue to a zeroclaw agent.

Runs from **any checkout** (home-lab, lies-exposed, …) — the skill lives in user
space. Paperclip creds and endpoints come from `~/.env` (template: dotfiles
`env.example`).
Runs as the orchestrator or a
sub-agent, over the **operator board-token** path — the same credential
`paperclip-plan-to-issue` and `paperclip-debug-run` use. It is **not** a
zeroclaw-pod skill; the pod holds no standing Paperclip credential.

## When to use / not use

- **Use** when you have a board issue identifier and want the work done now, in
  this checkout, with a normal branch + PR — a spec bug, a small feature, a
  config/helm change, a doc task.
- **Don't use** to *file* a plan onto the board — that is `paperclip-plan-to-issue`.
- **Don't use** to post-mortem a failed agent run — that is `paperclip-debug-run`.
- **Don't use** to dispatch the issue to zeroclaw's coder agent — that is the
  `zeroclaw-spawn-coder` command.
- If the issue is big enough to need its own decomposition, stop and say so —
  it should be a parent with sub-issues, not one PR.

## Prerequisites

- `kubectl` with the `$PAPERCLIP_KUBE_CONTEXT` context, namespace `$PAPERCLIP_NAMESPACE` (Paperclip
  lives there).
- `PAPERCLIP_BOARD_TOKEN` + `PAPERCLIP_COMPANY_ID` in `~/.env` (template: dotfiles `env.example`). On `401`,
  refresh with the `paperclip-board-token` skill.
- `gh` for the PR.

Paperclip is behind Cloudflare Access, so calls go **from inside the paperclip
pod** over localhost:

```bash
set -a; . ~/.env; set +a          # PAPERCLIP_BOARD_TOKEN, PAPERCLIP_COMPANY_ID
KX="kubectl --context "$PAPERCLIP_KUBE_CONTEXT" -n "$PAPERCLIP_NAMESPACE""
CID="$PAPERCLIP_COMPANY_ID"
PC() {  # PC <METHOD> <path>   — body on stdin for POST/PUT/PATCH
  $KX exec -i deploy/paperclip -- curl -s -X "$1" \
    -H "Authorization: Bearer $PAPERCLIP_BOARD_TOKEN" \
    -H "Content-Type: application/json" --data-binary @- "http://localhost:3100$2"
}
PCG() { $KX exec -i deploy/paperclip -- curl -s \
  -H "Authorization: Bearer $PAPERCLIP_BOARD_TOKEN" "http://localhost:3100$1"; }
```

`kubectl exec` prints a `Defaulted container "paperclip" …` line on stderr —
harmless, ignore it; stdout is clean JSON.

**`:issueId` in every `/api/issues/...` route is the identifier `HOM-NN`, not the
UUID.** An unmatched `/api/*` path returns the SPA `index.html` (a big HTML
blob), not a JSON 404 — check the path before calling, don't probe.

Never echo the token; never paste it (or any fetched secret) into an issue,
comment, document, commit, or PR.

## Guardrails

- **Every repo change is a PR**, branched off fresh `origin/main`, never pushed
  to `main` — even a one-line fix. (`[[feedback-always-use-pr]]`)
- **Concurrent git sessions.** Other sessions move HEAD / branches / the index
  mid-task. `git fetch` first; branch off `origin/main`; never `git add -A`;
  re-verify branch + HEAD immediately before every commit.
  (`[[homelab-concurrent-git-sessions]]`)
- **Only touch the target issue.** Do not check out, comment on, or transition
  any other issue. If a blocker or parent needs a change, report it — don't do
  it here.
- **Respect blockers.** If any `blockedByIssueIds` entry is not `done`, stop:
  the issue is not ready. Report which blocker is open.
- **`backlog` is not scheduled.** If the issue is `backlog`, confirm with the
  user before pulling it forward — someone parked it deliberately.
- **Board token may be read-only.** `plan-to-issue`-style writes (create,
  checkout, PATCH, comment) usually work, but a `403` means the token lacks that
  scope. On `403` for any write: do the implementation + PR anyway, then tell the
  user to flip the issue status by hand. Never block the code work on a board
  write.
- **Delegate service work.** If the issue targets one service, use `task` with
  the matching sub-agent (AGENTS.md rule 3) — it loads its own context. Don't
  read service files directly from the orchestrator.
- **Ticket references are links** in any comment / PR body:
  `[HOM-NN](/HOM/issues/HOM-NN)` (derive the `HOM` prefix from the returned
  `identifier`).

## Procedure

### Step 1 — Resolve + read the issue

```bash
ID="HOM-NN"
PCG "/api/companies/$CID/issues?q=$ID" | jq '.[] | {id,identifier,title,status}'
PCG "/api/issues/$ID"                  | jq '{identifier,title,status,priority,
      assigneeAgentId,assigneeUserId,parentId,blockedByIssueIds,executionState,
      description, ancestors: [.ancestors[]?.identifier]}'
PCG "/api/issues/$ID/comments?order=asc" | jq '.[] | {author:(.authorAgentId // .authorUserId), createdAt, body}'
PCG "/api/issues/$ID/documents"          | jq '.[] | {key,title,updatedAt}'
```

Pull the acceptance criteria out of the `description`. Read the comment thread
for clarifications, scope cuts, and board decisions made after the issue was
filed — they override the description.

### Step 2 — Read the plan context

Sub-issues filed by `paperclip-plan-to-issue` carry no plan of their own; the
plan lives on the **parent** as the `plan` document, and the sub-issue
description points at a section (`See the plan document on the parent (HOM-NN) §4`).

```bash
# this issue's own plan doc, if it has one:
PCG "/api/issues/$ID/documents/plan" | jq -r '.body // "no plan doc"'
# else the parent's:
PCG "/api/issues/<parentId-identifier>/documents/plan" | jq -r '.body'
```

Read the referenced section in full before touching code.

### Step 3 — Readiness gate

Stop and report instead of proceeding if any hold:

- `status` is `done` / `cancelled` → nothing to do.
- `status` is `backlog` → ask the user to confirm pulling it forward.
- Any `blockedByIssueIds` entry is not `done`
  (`PCG "/api/issues/<blocker>" | jq .status`) → blocked, name the blocker.
- The scope is too large for one PR → recommend decomposition
  (`paperclip-plan-to-issue` / `suggest_tasks`).
- The acceptance criteria are ambiguous and the thread doesn't resolve it →
  post one `ask_user_questions` interaction and stop.

### Step 4 — Check the issue out

```bash
echo '{}' | PC POST "/api/issues/$ID/checkout" | jq '{status, assigneeAgentId, assigneeUserId, error}'
```

- Success → issue is now `in_progress`, owned by the board token's principal.
- `409` → another assignee owns it. **Do not retry.** Stop and report.
- `403` → token can't check out. Fall back:
  `echo '{"status":"in_progress","comment":"Operator picking this up."}' | PC PATCH "/api/issues/$ID"`.
  If that also `403`s / `422`s, continue with the code work and tell the user to
  set `in_progress` by hand.

Post a starting comment so the board sees the work is live:

```bash
jq -n --arg b "Picked up by the operator. Implementing on a branch; PR to follow." \
  '{body:$b}' | PC POST "/api/issues/$ID/comments" >/dev/null
```

### Step 5 — Implement

```bash
git fetch origin -q
git checkout -b hom-nn/<short-slug> origin/main
```

- Route by target. Issue scoped to one service → `task` with that sub-agent,
  handing it the acceptance criteria + the relevant plan section. Cross-cutting
  or infra/docs → implement here, following
  `context/design-patterns/DESIGN-PATTERNS.md` (FP / TaskEither / DRY in TS —
  `[[fp-ts-effect-preference]]`).
- Keep the change to the issue's stated scope. New scope you discover →
  a follow-up note in the report, not extra commits.
- Stage explicit paths only (`git add <path> …`), never `git add -A`.

### Step 6 — Validate

Run the narrowest meaningful check for what changed — package build / lint /
unit tests for a touched service, `helm template` / `helmfile lint` for a chart,
a schema check for a data file. Report the real outcome; if something fails and
you can't fix it in scope, say so and leave the issue `in_progress`.

### Step 7 — Commit + PR

Re-verify first (concurrent sessions):

```bash
test "$(git branch --show-current)" = "hom-nn/<short-slug>" || { echo "branch moved"; exit 1; }
git rev-parse --short HEAD; git status --porcelain
git commit -m "$(cat <<'EOF'
<type>(<scope>): <what> — HOM-NN

<why, from the issue / plan section>

<attribution trailer(s) your harness asks for, if any>
EOF
)"
git push -u origin HEAD
gh pr create --fill --body "$(cat <<'EOF'
Implements [HOM-NN](/HOM/issues/HOM-NN).

## Acceptance
- <criterion> — <how this PR meets it>

## Validation
- <command> → <result>

<attribution footer your harness asks for, if any>
EOF
)"
```

### Step 8 — Park the issue in `in_review`

The PR + the user as reviewer is the real review path the disposition guard
requires. Set status and drop the PR link in one call:

```bash
jq -n --arg url "<PR-URL>" '{
  status: "in_review",
  comment: ("Implemented. PR open for review: " + $url + "\nMerging the PR completes this issue.")
}' | PC PATCH "/api/issues/$ID" | jq '{status, error}'
```

- `invalid_issue_disposition` / `422` → the guard doesn't see a live review
  path. Leave the issue `in_progress`, post the PR link as a plain comment, and
  tell the user to move it to `in_review` (or assign a reviewer) themselves.
- Do **not** set `done` — the merge does that, or the user does.

### Step 9 — Context update (AGENTS.md rule 8)

Walk the §Self-Update Rules table. If the work surfaced a durable fact — a
corrected codebase assumption, a design decision, a reusable playbook, a new
glossary term — write it to the right `context/` file on this same branch. If
nothing qualifies, skip. Also run `mem0_memory_search` / `mem0_memory_add`
(`homelab-orchestrator`) for an ephemeral lesson.

### Step 10 — Report

```markdown
## Implemented — HOM-NN <title>

**Issue:** HOM-NN · was <status> → now <in_review | in_progress (guard rejected) | unchanged (403)>
**PR:** <url>
**Checked out as:** board-token principal | fell back to PATCH | manual (told user)

### Change
- <files touched, one line each>

### Validation
- <command> → pass/fail

### Acceptance
- <criterion> → met / partial (why)

### Follow-up / not done
- <deferred scope, blockers hit, guard fallback the user must clear>

### Context update
- <file + entry id, or "none">
```

## Notes

- `GET /api/issues/{id}` embeds `ancestors` but not `children` / `documents` —
  list children with `?parentId=`, fetch docs via `/documents/:key`.
- `PATCH /api/issues/{id}` accepts `status` and `comment` together; the response
  echoes `changes` and the authoritative post-state.
- One issue at a time. Don't batch-implement a parent's whole sub-issue list in
  one session — each sub-issue is its own PR.
- If checkout succeeded under the board token but the issue was assigned to an
  agent, that agent will no longer wake for it. Note that in the report so the
  user can re-assign after merge if they want the agent to keep ownership.
