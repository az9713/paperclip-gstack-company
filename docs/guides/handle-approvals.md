# Handle Approvals

What happens when an agent creates a checkpoint approval, how to find it, how to respond, and what happens after you approve or reject.

---

## What Triggers an Approval

An approval is created when an agent hits a **judgment-call checkpoint** — a decision that requires human context, not just a sensible default. In the Engineering Company, these are:

| Skill | Checkpoint | When |
|-------|-----------|------|
| `/review` | ASK items | Review finds issues requiring judgment |
| `/review` | Greptile false positive | Automated review comment appears wrong |
| `/land-and-deploy` | Pre-merge readiness gate | Always, before every merge |
| `/land-and-deploy` | Deploy failure | Deploy pipeline fails |
| `/land-and-deploy` | Production health issues | Canary checks fail post-deploy |
| `/autoplan` | Premise confirmation | Phase 1 always |
| `/autoplan` | Final approval gate | Phase 4 always |
| `/qa` | WTF-likelihood > 20% | QA is getting chaotic — should we continue? |
| `/ship` | Coverage below threshold | Test coverage dropped below minimum |
| `/ship` | Plan items not done | PLAN.md has unchecked critical items |

Purely mechanical decisions (version bump number, stash dirty tree, auto-fix review findings) are never escalated — they are decided automatically using sensible defaults. See [Checkpoint Map](../reference/checkpoint-map.md) for the full list.

---

## What the Agent Does When It Creates an Approval

When an agent hits a judgment checkpoint, it:

1. Creates a `gstack_checkpoint` approval via the Paperclip API
2. Links the approval to the current issue
3. Posts a comment on the issue with the question, options, and a recommendation
4. Sets the issue status to `blocked`
5. Exits the run

The issue will show as **Blocked** in the Issues board, and there will be a pending approval in the Approvals panel.

---

## Find Pending Approvals

### Via Web UI

1. Open [http://localhost:3100](http://localhost:3100)
2. In the left sidebar, click **Approvals**
3. Pending approvals appear at the top with status `pending`

You can also find the approval from the issue:
1. Open the Issues board
2. Find a task with status **Blocked** (shown with a red indicator)
3. Click the task
4. In the comment thread, find the agent's checkpoint comment — it includes a link to the approval

### Via API

```bash
curl -s "http://localhost:3100/api/companies/<COMPANY_ID>/approvals?status=pending" | \
  jq '[.[] | {id, type, createdAt, payload: .payload.question}]'
```

---

## Read the Checkpoint Question

Each approval has a payload with the skill name, step, question, options, recommendation, and context. Example:

```json
{
  "type": "gstack_checkpoint",
  "status": "pending",
  "payload": {
    "skill": "review",
    "step": "ASK items",
    "question": "Found 2 items requiring judgment. How should we proceed?",
    "options": [
      {
        "key": "A",
        "label": "Fix both items inline in this PR"
      },
      {
        "key": "B",
        "label": "Fix #1 (SQL injection in auth), defer #2 (missing rate limiting) to a separate PR"
      },
      {
        "key": "C",
        "label": "Defer both items to separate PRs"
      }
    ],
    "recommendation": "A",
    "context": "Item #1 is a critical SQL injection risk in the auth middleware. Item #2 is missing rate limiting on the login endpoint — not exploitable yet but should be fixed soon."
  }
}
```

The agent always provides a **recommendation** (the option it thinks is best) and **context** explaining why the decision matters. Read the context before choosing.

Also read the issue comments — the agent posts a formatted version of the question in the issue thread which may be easier to read than the raw JSON payload.

---

## Respond to an Approval

### Via Web UI

1. Open the approval (from Approvals panel or from the issue comment link)
2. Read the question and options
3. Select your choice (click the option button)
4. Optionally, add a **Decision Note** explaining your reasoning
5. Click **Approve** (or **Reject** / **Request Revision**)

### Via API

**Approve (proceed with a specific option):**
```bash
curl -X PATCH http://localhost:3100/api/approvals/<APPROVAL_ID> \
  -H "Content-Type: application/json" \
  -d '{
    "status": "approved",
    "decisionNote": "Option B. Fix the SQL injection now — that is critical path. Rate limiting is important but not blocking."
  }'
```

**Reject (stop this work):**
```bash
curl -X PATCH http://localhost:3100/api/approvals/<APPROVAL_ID> \
  -H "Content-Type: application/json" \
  -d '{
    "status": "rejected",
    "decisionNote": "Do not proceed. This PR is too large. Split into smaller PRs first."
  }'
```

**Request revision (changes needed before proceeding):**
```bash
curl -X PATCH http://localhost:3100/api/approvals/<APPROVAL_ID> \
  -H "Content-Type: application/json" \
  -d '{
    "status": "revision_requested",
    "decisionNote": "Before fixing the SQL injection, add a test that reproduces it first. Then fix it. This ensures the fix actually addresses the issue."
  }'
```

---

## What Happens After You Approve

1. **Paperclip detects the approval is resolved**
2. **Paperclip generates a wake event** for the agent that created the approval (`wakeReason: "approval_resolved"`)
3. **Agent wakes on its next heartbeat** with `PAPERCLIP_APPROVAL_ID` set in its environment
4. **Agent reads the gstack-bridge skill** → detects `PAPERCLIP_APPROVAL_ID` → jumps to the Resume Protocol
5. **Agent fetches the approval** via `GET /api/approvals/{PAPERCLIP_APPROVAL_ID}`
6. **Agent reads your `decisionNote`** and the approval status
7. **Agent resumes the gstack skill** from where it left off, using your answer
8. **Agent unblocks the issue** (`PATCH /api/issues/{id}` → `status: "in_progress"`)
9. Work continues

The `--resume <sessionId>` flag ensures the agent's full conversation context is restored — it knows which skill it was running, which step it was on, and what it had already done. Your approval answer is the equivalent of typing your answer at the `AskUserQuestion` prompt in interactive mode.

---

## What Happens After You Reject

1. Agent reads the approval with `status: "rejected"`
2. Agent reads your `decisionNote`
3. Agent posts a comment on the issue explaining what was stopped and why
4. Agent sets the issue to `done` or `cancelled` as appropriate (based on your note)
5. Agent exits

If you rejected because the task scope was wrong, you may want to create a new, more focused task. The rejected task is closed; it does not automatically resume.

---

## What Happens After You Request Revision

1. Agent reads the approval with `status: "revision_requested"`
2. Agent reads your `decisionNote` for the requested changes
3. Agent applies the requested changes
4. Agent continues the skill workflow from where it left off (with the revision applied)

This is useful when you want the agent to do something slightly different than any of the pre-defined options — e.g., "add a test that reproduces the bug before fixing it."

---

## The Pre-Merge Gate: Always Requires Approval

The `/land-and-deploy` skill always creates an approval at the pre-merge readiness gate — regardless of test status, review status, or anything else. This is intentional: a human should always confirm before production deploys.

The gate shows:
- Test suite status (pass/fail, count)
- CI pipeline status
- Code review status (reviewed by whom, when)
- Diff summary (files changed, lines added/removed)
- Any open blocking items

Read this information carefully before approving a deploy. You are the final gate before code reaches production.
