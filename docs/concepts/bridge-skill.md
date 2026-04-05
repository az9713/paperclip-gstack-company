# The gstack-Bridge Skill

The `gstack-bridge` skill is the integration layer that makes gstack skills work inside Paperclip's headless execution environment. This document explains why it exists, exactly how it works, and the full protocols it defines.

---

## Why the Bridge Skill Exists

gstack skills are designed for interactive use. When a human runs `/review` in a Claude Code session, the skill pauses at judgment-call moments and calls `AskUserQuestion` — Claude presents options to the human in the terminal and waits for a response before continuing.

Paperclip runs agents headlessly: `claude --print - --output-format stream-json --verbose --dangerously-skip-permissions`. There is no human at the terminal. If an agent calls `AskUserQuestion` in this mode, one of two things happens:
1. The call times out with no response, and the agent is stuck
2. The call fails, and the skill aborts mid-workflow

The bridge skill solves this by teaching agents — at the prompt level — to replace `AskUserQuestion` with a Paperclip-native approval flow. No changes to gstack templates are needed. No changes to the Paperclip adapter are needed. The integration lives entirely in the bridge skill prompt.

The bridge skill is located at `companies/engineering/skills/gstack-bridge/SKILL.md` and is mounted for every agent in the Engineering Company alongside their role-specific gstack skills.

---

## Step 0: Confirm Paperclip Mode

The first thing the bridge skill teaches agents is how to detect that they are in Paperclip mode:

```
PAPERCLIP_AGENT_ID     — set by Paperclip
PAPERCLIP_COMPANY_ID   — set by Paperclip
PAPERCLIP_API_URL      — set by Paperclip
PAPERCLIP_API_KEY      — set by Paperclip
PAPERCLIP_RUN_ID       — set by Paperclip
```

All five must be present for Paperclip mode rules to apply. If they are absent, the agent is running interactively and should follow gstack skill instructions as written — including calling `AskUserQuestion`.

This means the bridge skill is safe to use in both modes without any adapter configuration. In interactive mode, it is a no-op.

---

## Step 1: Identify the Task

Before running any gstack skill, the agent reads the wake context:

1. Check `PAPERCLIP_WAKE_PAYLOAD_JSON` — compact summary of the current task with recent comments
2. If absent or `fallbackFetchNeeded` is true: `GET /api/issues/{PAPERCLIP_TASK_ID}` for the full task
3. **If `PAPERCLIP_APPROVAL_ID` is set:** skip directly to the Resume Protocol — the agent was woken to continue an interrupted skill

The task context tells the agent what to work on. The wake reason (`PAPERCLIP_WAKE_REASON`) tells it why it was woken.

---

## Step 2: Select the Correct gstack Skill

The bridge skill maps issue characteristics to gstack skills. The agent checks signals in this priority order:

1. **Explicit command** in issue title or description: "run /review", "/ship this branch"
2. **Issue label**: `review` → `/review`, `ship` → `/ship`, `qa` → `/qa`
3. **Title keywords** (see mapping table in the bridge skill)

| Keywords | gstack skill |
|----------|-------------|
| "review PR", "code review", "pre-landing" | `/review` |
| "ship", "create PR", "bump version" | `/ship` |
| "QA", "find bugs", "quality check" | `/qa` or `/qa-only` |
| "deploy", "merge", "land", "go live" | `/land-and-deploy` |
| "canary", "post-deploy", "monitor" | `/canary` |
| "review plan" + CEO context | `/plan-ceo-review` |
| "review plan" + CTO context | `/plan-eng-review` |
| "autoplan", "full plan review" | `/autoplan` |
| "debug", "investigate", "root cause" | `/investigate` |
| "security", "audit", "OWASP" | `/cso` |
| "design review", "UI review" | `/design-review` |
| "design to HTML", "convert design" | `/design-html` |
| "DX review", "developer experience" | `/devex-review` |
| "retro", "retrospective" | `/retro` |
| "benchmark", "performance regression" | `/benchmark` |
| "document release", "release notes" | `/document-release` |

If no skill matches, the agent posts a comment asking for clarification and sets the issue to `blocked`.

---

## The Three-Tier Checkpoint Decision Model

The core of the bridge skill is how it handles the decision points that gstack skills encounter:

### Tier 1: Mechanical Decisions — Auto-Decide

These are decisions where the right answer is deterministic and well-defined. The agent decides silently without creating an approval:

| Decision | Default |
|----------|---------|
| Version bump level | MICRO (4th digit), unless description specifies otherwise |
| Dirty working tree in `/qa` | Stash and continue |
| AUTO-FIX review findings | Always apply all of them |
| CHANGELOG content | Auto-generate from diff following existing style |
| Commit messages | Auto-write following project conventions |
| Test coverage within threshold | Continue without stopping |
| Plan items already done | Mark verified and continue |
| TODOS.md missing | Create it automatically |

### Tier 2: Judgment Decisions — Create Approval

These are decisions where the right answer depends on business context, risk tolerance, or product direction that the human needs to weigh in on:

| Decision | Skill |
|----------|-------|
| ASK items from `/review` | `/review`, `/ship` |
| Greptile comments that appear to be false positives | `/review` |
| MINOR or MAJOR version bump (strong signals only) | `/ship` |
| Pre-merge readiness gate | `/land-and-deploy` |
| Deploy failure decisions | `/land-and-deploy` |
| Production health issues post-deploy | `/land-and-deploy` |
| `/autoplan` premise confirmation | `/autoplan` |
| `/autoplan` final approval gate | `/autoplan` |
| Coverage below threshold | `/qa`, `/ship` |
| WTF-likelihood > 20% in `/qa` | `/qa` |

### Tier 3: Pre-Answered Decisions — Use the Answer

If the issue description or a prior comment already answers the question (e.g., "use MINOR bump", "skip all Greptile false positives", "fix all ASK items"), the agent uses that answer directly without creating an approval.

---

## The Approval Protocol (4 Steps)

When an agent hits a Tier 2 (judgment) checkpoint, it executes this four-step protocol:

### Step 4a: Create the Approval

```http
POST /api/companies/{PAPERCLIP_COMPANY_ID}/approvals
Authorization: Bearer $PAPERCLIP_API_KEY
X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
Content-Type: application/json

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

Response contains the `approvalId` — used in subsequent calls.

### Step 4b: Link the Approval to the Issue

```http
POST /api/approvals/{approvalId}/issues
Content-Type: application/json

{ "issueId": "{PAPERCLIP_TASK_ID}" }
```

This creates the association so the approval appears when a human views the issue.

### Step 4c: Post a Comment on the Issue

```http
POST /api/issues/{PAPERCLIP_TASK_ID}/comments
X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
Content-Type: application/json

{
  "body": "## gstack checkpoint: {skill}/{step}\n\n{question}\n\n**Options:**\n- A) {option A}\n- B) {option B}\n\n**Recommendation:** A — {reason}\n\nApproval: [View]({PAPERCLIP_API_URL}/approvals/{approvalId})"
}
```

This makes the checkpoint question visible in the issue's comment thread, so humans can understand the context before opening the approval.

### Step 4d: Set Issue to Blocked and Exit

```http
PATCH /api/issues/{PAPERCLIP_TASK_ID}
X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
Content-Type: application/json

{
  "status": "blocked",
  "comment": "Waiting for human decision on {skill} checkpoint: {step}. See approval."
}
```

The agent exits the run. Paperclip schedules a wake event when the approval is resolved.

---

## The Resume Protocol (4 Steps)

When the human resolves the approval, Paperclip re-wakes the agent with `PAPERCLIP_APPROVAL_ID` set. The bridge skill teaches the agent to:

### Step 5a: Fetch the Approval

```http
GET /api/approvals/{PAPERCLIP_APPROVAL_ID}
Authorization: Bearer $PAPERCLIP_API_KEY
```

### Step 5b: Read the Decision

| Status | Meaning | Action |
|--------|---------|--------|
| `approved` | Human said proceed | Read `decisionNote` or comments for which option was selected |
| `rejected` | Human said stop | Post comment explaining the stop, set issue to `done` or `cancelled` |
| `revision_requested` | Human wants changes first | Read comment, apply requested changes, then continue |

### Step 5c: Continue the gstack Skill

The agent uses `--resume <sessionId>` which restored its full conversation context. It knows which skill it was running and which step it was on. It continues from that step using the human's answer as the response to the checkpoint.

### Step 5d: Unblock the Issue

```http
PATCH /api/issues/{PAPERCLIP_TASK_ID}
Content-Type: application/json

{ "status": "in_progress" }
```

Work resumes as if the checkpoint had been answered inline.

---

## The Delegation Protocol

When a gstack skill would cross a role boundary — requiring expertise that belongs to a different agent — the bridge skill converts this into a subtask delegation.

### When Delegation Applies

| gstack internal phase | Paperclip delegation target |
|----------------------|----------------------------|
| `/autoplan` design review phase | DesignLead → `/plan-design-review` |
| `/autoplan` eng review phase | CTO → `/plan-eng-review` |
| `/autoplan` DX review phase | DevExEngineer → `/plan-devex-review` |
| `/ship` triggers a review | CTO creates review subtask for itself |
| QALead finds a bug via `/qa-only` | QAEngineer → `/qa` |

### Creating a Delegation Subtask

```http
POST /api/companies/{PAPERCLIP_COMPANY_ID}/issues
X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
Content-Type: application/json

{
  "title": "<task title>",
  "description": "<context from current task>",
  "parentId": "{PAPERCLIP_TASK_ID}",
  "assigneeAgentId": "<target-agent-id>",
  "status": "todo",
  "priority": "high"
}
```

After creating the subtask, the delegating agent sets its own issue to `in_review` and exits. The target agent picks up the subtask on its next heartbeat, completes the work, and sets it to `done`. The delegating agent sees the completed subtask on its next wake and continues.

---

## Co-Authorship Requirement

Every git commit made while running a gstack skill must include this co-author line:

```
Co-Authored-By: Paperclip <noreply@paperclip.ing>
```

This is a fixed string — always `Paperclip`, never the agent's name. It attributes the commit to the Paperclip system without identifying individual agents, which keeps the git log clean and auditable.

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| `PAPERCLIP_APPROVAL_ID` is set | Jump to Resume Protocol immediately |
| gstack skill says "never stop for X" | Auto-decide using Tier 1 defaults |
| gstack skill says "always stop for X" | Run Approval Protocol (4 steps) |
| Issue description has the answer | Use it directly (Tier 3) |
| Skill would cross role boundary | Delegation Protocol |
| About to call `AskUserQuestion` | NEVER — use approval or auto-decide |
| Making a git commit | Add `Co-Authored-By: Paperclip <noreply@paperclip.ing>` |
