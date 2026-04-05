---
name: gstack-bridge
description: >
  Bridge between gstack engineering skills and Paperclip orchestration.
  Teaches agents how to operate gstack skills in Paperclip's headless
  execution mode. Read this skill FIRST before running any gstack skill.
  Required for all agents in the gstack-powered Engineering Company.
---

# gstack-Paperclip Bridge

You are running **gstack engineering skills inside Paperclip's headless orchestration**. This changes how you handle interactive checkpoints and cross-role handoffs. Read this skill completely before invoking any gstack skill.

---

## Step 0: Confirm Paperclip Mode

You are in Paperclip mode when ALL of these env vars are present:

```
PAPERCLIP_AGENT_ID
PAPERCLIP_COMPANY_ID
PAPERCLIP_API_URL
PAPERCLIP_API_KEY
PAPERCLIP_RUN_ID
```

If they are present, all rules in this skill apply. If absent, you are running interactively — follow the gstack skill instructions as written.

---

## Step 1: Identify Your Task

Read the Paperclip wake context:

1. Check `PAPERCLIP_WAKE_PAYLOAD_JSON` (fastest path — compact issue summary with new comments)
2. If absent or `fallbackFetchNeeded` is true: `GET /api/issues/{PAPERCLIP_TASK_ID}` for full context
3. Read the issue title, description, and comments to understand the task

**If `PAPERCLIP_APPROVAL_ID` is set:** You are resuming from a checkpoint. Go to **Step 5: Resume Protocol** immediately.

---

## Step 2: Select the Correct gstack Skill

Map the issue to the appropriate gstack skill using these signals (in priority order):

1. **Explicit command in issue title or description** — if the issue says "run /review" or "/ship", use that
2. **Issue label** — label `review` → `/review`, `ship` → `/ship`, `qa` → `/qa`, etc.
3. **Title keywords:**

| Keywords in title/description | gstack skill |
|-------------------------------|-------------|
| "review PR", "code review", "pre-landing" | `/review` |
| "ship", "create PR", "bump version", "release" | `/ship` |
| "QA", "find bugs", "test", "quality check" | `/qa` or `/qa-only` |
| "deploy", "merge", "land", "go live" | `/land-and-deploy` |
| "canary", "post-deploy", "monitor" | `/canary` |
| "review plan", "plan review" (CEO) | `/plan-ceo-review` |
| "review plan", "eng review" (CTO) | `/plan-eng-review` |
| "review plan", "design review" | `/plan-design-review` |
| "review plan", "devex review" | `/plan-devex-review` |
| "autoplan", "full plan review" | `/autoplan` |
| "debug", "investigate", "root cause", "broken" | `/investigate` |
| "security", "audit", "OWASP", "vulnerability" | `/cso` |
| "design system", "design from scratch" | `/design-consultation` |
| "design review", "UI review" | `/design-review` |
| "design to HTML", "convert design" | `/design-html` |
| "DX review", "developer experience" | `/devex-review` |
| "retro", "retrospective" | `/retro` |
| "benchmark", "performance regression" | `/benchmark` |
| "document release", "release notes" | `/document-release` |

If no skill matches clearly, post a comment asking the board for clarification and set issue to `blocked`.

---

## Step 3: The AskUserQuestion Rule

**NEVER call `AskUserQuestion` in Paperclip mode.** It will fail — there is no human at the terminal.

Instead, classify each checkpoint the gstack skill encounters:

### Mechanical decisions — auto-decide silently

These appear in gstack skill templates as "never stop for" items. Decide automatically:

- **Version bump level:** Use MICRO (4th digit) unless the issue description specifies MINOR or MAJOR
- **Dirty working tree in /qa:** Always stash and continue
- **AUTO-FIX review findings:** Always apply all auto-fixes
- **CHANGELOG content:** Write it following existing style
- **Commit message approval:** Write the commit and proceed
- **Test coverage within threshold:** Continue without asking
- **Plan items already done:** Mark verified and continue

### Judgment decisions — create approval

These appear in gstack skill templates as "always stop for" items. Use the **Approval Protocol** (Step 4):

- ASK items from `/review` (fix vs. skip for each issue)
- Greptile comments needing human judgment (valid vs. false positive)
- Version bump MINOR or MAJOR (only when signals suggest non-MICRO)
- Pre-merge readiness gate in `/land-and-deploy` (always)
- Deploy failure decisions in `/land-and-deploy`
- Production health issues post-deploy
- `/autoplan` premise confirmation (Phase 1)
- `/autoplan` final approval gate (Phase 4)
- Coverage below threshold (hard gate)
- Plan items NOT DONE (when critical)

### Pre-answered decisions — use the answer

If the issue description or a prior comment contains an explicit answer (e.g., "use MINOR bump", "skip Greptile false positives", "fix all ASK items"), use that answer directly. No approval needed.

---

## Step 4: Approval Protocol

When you hit a judgment checkpoint:

**4a. Create the approval:**
```
POST /api/companies/{PAPERCLIP_COMPANY_ID}/approvals
Headers: Authorization: Bearer $PAPERCLIP_API_KEY, X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
{
  "type": "gstack_checkpoint",
  "requestedByAgentId": "{PAPERCLIP_AGENT_ID}",
  "payload": {
    "skill": "<gstack-skill-name>",
    "step": "<step name from the skill>",
    "question": "<the question being asked>",
    "options": [
      { "key": "A", "label": "<option A text>" },
      { "key": "B", "label": "<option B text>" }
    ],
    "recommendation": "A",
    "context": "<why this decision matters>"
  }
}
```

**4b. Link approval to the issue:**
```
POST /api/approvals/{approvalId}/issues
{ "issueId": "{PAPERCLIP_TASK_ID}" }
```

**4c. Post a comment on the issue** with the checkpoint question formatted clearly:
```
POST /api/issues/{PAPERCLIP_TASK_ID}/comments
Headers: X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
{
  "body": "## gstack checkpoint: {skill}/{step}\n\n{question}\n\n**Options:**\n- A) {option A}\n- B) {option B}\n\n**Recommendation:** A — {reason}\n\nApproval: [View]({PAPERCLIP_API_URL}/{prefix}/approvals/{approvalId})"
}
```

**4d. Set issue to blocked and exit:**
```
PATCH /api/issues/{PAPERCLIP_TASK_ID}
Headers: X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
{ "status": "blocked", "comment": "Waiting for human decision on {skill} checkpoint: {step}. See approval." }
```

Exit the run. The Paperclip system will re-wake you when the human responds.

---

## Step 5: Resume Protocol

When you wake with `PAPERCLIP_APPROVAL_ID` set:

**5a. Fetch the approval:**
```
GET /api/approvals/{PAPERCLIP_APPROVAL_ID}
```

**5b. Read the decision:**
- `status: "approved"` → the human chose to proceed. Check `decisionNote` or the approval comments for which option they selected (A, B, C, etc.)
- `status: "rejected"` → the human chose to stop. Post a comment explaining what was stopped and why, set issue to `done` or `cancelled` as appropriate
- `status: "revision_requested"` → the human wants changes before proceeding. Read their comment, apply changes, then continue

**5c. Continue the gstack skill** from where it left off, using the approval response as the answer to the checkpoint. The `--resume` flag on Claude means your prior context is intact — you should remember which step you were on.

**5d. Unblock the issue:**
```
PATCH /api/issues/{PAPERCLIP_TASK_ID}
{ "status": "in_progress" }
```

---

## Step 6: Delegation Protocol

Some gstack skills chain multiple role-specific phases sequentially (e.g., `/autoplan` runs CEO → design → eng → DX review in one session). In Paperclip, **these cross-role phases become subtasks delegated to the appropriate agent**.

When a gstack skill would cross a role boundary:

| gstack internal phase | Paperclip delegation |
|-----------------------|----------------------|
| `/autoplan` design review phase | Create subtask → assign to DesignLead (`/plan-design-review`) |
| `/autoplan` eng review phase | Create subtask → assign to CTO (`/plan-eng-review`) |
| `/autoplan` DX review phase | Create subtask → assign to DevExEngineer (`/plan-devex-review`) |
| `/ship` triggers review | Create subtask → assign to CTO (`/review`) |
| QA Lead finds a bug | Create subtask → assign to QAEngineer (`/qa`) |

**Creating a delegation subtask:**
```
POST /api/companies/{PAPERCLIP_COMPANY_ID}/issues
Headers: X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
{
  "title": "<task title>",
  "description": "<context from current task>",
  "parentId": "{PAPERCLIP_TASK_ID}",
  "assigneeAgentId": "<target-agent-id>",
  "status": "todo",
  "priority": "high"
}
```

After creating the subtask, set your current issue to `in_review` and wait. The subtask agent will complete their work and you will pick up the result on the next heartbeat.

---

## Step 7: Commit Co-authorship

If you make any git commit while running a gstack skill, you MUST add EXACTLY this co-author line:

```
Co-Authored-By: Paperclip <noreply@paperclip.ing>
```

Do not put your agent name. Always use `Co-Authored-By: Paperclip <noreply@paperclip.ing>`.

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| `PAPERCLIP_APPROVAL_ID` is set | Jump to Step 5: Resume Protocol |
| gstack skill says "never stop for X" | Auto-decide using defaults |
| gstack skill says "always stop for X" | Step 4: Approval Protocol |
| Issue description has the answer | Use it directly |
| Skill would cross role boundary | Step 6: Delegation Protocol |
| Need to call `AskUserQuestion` | NEVER — use approval or auto-decide |
| Making a git commit | Add `Co-Authored-By: Paperclip <noreply@paperclip.ing>` |
