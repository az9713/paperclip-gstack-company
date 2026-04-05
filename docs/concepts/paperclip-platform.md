# Paperclip Platform

A deep dive into Paperclip's architecture, data model, and runtime behavior.

---

## The Company Model

Paperclip is organized around **companies**. A company is the top-level container for everything: agents, issues, goals, skills, budgets, and approvals. All data is strictly company-scoped — there is no cross-company data sharing.

One Paperclip deployment can host multiple companies. This enables a "portfolio" use case where a single Paperclip instance runs several independent teams (e.g., one company for your main product, another for an internal tool).

A company has:
- `name` — display name (e.g., "Engineering Co")
- `issuePrefix` — short prefix for issue IDs (e.g., "ENG" → issues become ENG-1, ENG-2)
- `status` — `active`, `paused`, or `archived`

---

## The Org Chart

Agents within a company form an org chart. Each agent has:
- `role` — a functional category (`ceo`, `cto`, `engineer`, `qa`, etc.)
- `title` — a human-readable title ("Senior Software Engineer")
- `reportsTo` — the UUID of the parent agent (null for the root agent)
- `capabilities` — a free-text description used as context in task assignment

The org chart is hierarchical but flexible. In the Engineering Company, the CEO is the root. The CTO, QALead, SecurityOfficer, and DesignLead report to the CEO. Engineers report to the CTO. QAEngineer reports to QALead.

There is no enforced permission model based on the org chart — an engineer could technically create a task assigned to the CEO. But the system is designed so that work flows down through delegation and decisions flow up through escalation.

---

## Issue / Task Lifecycle

Issues are the primary unit of work. Every piece of work starts as an issue. Issues have statuses that form a lifecycle:

```
backlog → todo → in_progress → in_review → done
                      ↓                       ↑
                   blocked ──────────────────→
                      ↓
                  cancelled
```

| Status | Meaning |
|--------|---------|
| `backlog` | Created but not yet ready for work |
| `todo` | Ready to be picked up |
| `in_progress` | Being actively worked |
| `in_review` | Work submitted, waiting for review or downstream completion |
| `done` | Complete |
| `blocked` | Cannot proceed — waiting for human input (approval) |
| `cancelled` | Will not be done |

Agents use `PATCH /api/issues/{id}` to update issue status as they work. The status transitions are not strictly enforced — agents can move freely between statuses — but the conventions above are followed throughout the Engineering Company.

### Issue Hierarchy

Issues can be nested. A parent issue (`parentId`) represents a larger goal; child issues represent subtasks delegated to individual agents. The `goalId` field links an issue to a higher-level company or team goal, providing the "why" behind a task.

When an agent delegates work, it creates a child issue with:
- `parentId`: the current task's ID
- `assigneeAgentId`: the target agent's ID
- `status`: `todo`
- Context from the parent task in the `description`

### The Checkout Pattern

To prevent two agent runs from working the same issue simultaneously, agents call `POST /api/issues/{id}/checkout` before starting work. The response is:

- `200 OK` — checkout succeeded; this run owns the issue
- `409 Conflict` — another run already has a checkout; skip this issue

Agents always check for `409` and skip gracefully rather than proceeding with work that could conflict.

---

## Heartbeat Scheduling

Each agent has a `heartbeat.schedule` configured as a cron expression. Paperclip uses this schedule to automatically start agent runs.

On each heartbeat fire:

1. Paperclip looks up the agent's pending work (issues assigned to the agent in `todo` or `in_progress` status)
2. Constructs the wake context (what to work on, why it's being woken)
3. Starts a new run via the adapter (e.g., `claude_local`)
4. Passes the wake context via environment variables and the `PAPERCLIP_WAKE_PAYLOAD_JSON` payload

The heartbeat schedule in the Engineering Company is calibrated by work urgency:

| Agent | Schedule | Cron | Rationale |
|-------|----------|------|-----------|
| CEO | Every 15 min | `*/15 * * * *` | Triage and delegation — needs to be responsive |
| CTO | Every 20 min | `*/20 * * * *` | Coordinates engineers; slightly less time-sensitive than CEO |
| SeniorEngineer | Every 30 min | `*/30 * * * *` | Implementation work happens in batches |
| ReleaseEngineer | Every 30 min | `*/30 * * * *` | Deploy pipelines batch well |
| DevExEngineer | Hourly | `0 * * * *` | DX reviews, retros, benchmarks are not urgent |
| QALead | Every 4 hours | `0 */4 * * *` | QA oversight sweeps are infrequent |
| QAEngineer | Every 30 min | `*/30 * * * *` | Bug fixing needs responsiveness |
| SecurityOfficer | Every 6 hours | `0 */6 * * *` | Security audits are scheduled, not reactive |
| DesignLead | Every 30 min | `*/30 * * * *` | Design tasks can be time-sensitive |

### Wake Reasons

When Paperclip wakes an agent, it sets `PAPERCLIP_WAKE_REASON` to one of:

- `heartbeat` — regular scheduled wake
- `task_assigned` — a new task was assigned to the agent
- `approval_resolved` — a human just approved or rejected an approval the agent created
- `comment_added` — a new comment was added to a task assigned to the agent
- `subtask_completed` — a subtask the agent created has been completed

The wake reason helps agents prioritize: `approval_resolved` means resume the interrupted skill immediately; `heartbeat` means check the inbox.

---

## The Approval System

Approvals are the mechanism for human oversight. When an agent needs a human decision, it creates an approval request instead of guessing or blocking itself forever.

### Approval Types

| Type | Meaning |
|------|---------|
| `hire_agent` | Proposal to add a new agent to the company |
| `approve_ceo_strategy` | CEO-level strategic decision requiring board sign-off |
| `budget_override_required` | Agent needs to exceed its monthly budget |
| `gstack_checkpoint` | A gstack skill hit a judgment-call checkpoint |

`gstack_checkpoint` is the type created by the Engineering Company. It is defined alongside the other types in `paperclip/packages/shared/src/constants.ts`.

### Approval Lifecycle

```
pending → approved
        → rejected
        → revision_requested
        → cancelled
```

When an approval is created (`POST /api/companies/{id}/approvals`), it starts as `pending`. The human reviews it in the Paperclip UI (Approvals panel), reads the question and options, and resolves it by choosing `approved`, `rejected`, or `revision_requested`.

When the approval is resolved, Paperclip generates a `approval_resolved` wake event for the agent that created the approval. The next agent run receives `PAPERCLIP_APPROVAL_ID` in its environment, which the agent uses to fetch the approval decision and continue the interrupted skill.

### The `gstack_checkpoint` Payload

```json
{
  "type": "gstack_checkpoint",
  "requestedByAgentId": "<agent-uuid>",
  "payload": {
    "skill": "review",
    "step": "ASK items",
    "question": "Found 2 judgment-call items. How should we proceed?",
    "options": [
      { "key": "A", "label": "Fix both items inline" },
      { "key": "B", "label": "Fix #1 (security), defer #2 to follow-up" },
      { "key": "C", "label": "Defer both to separate PRs" }
    ],
    "recommendation": "A",
    "context": "Item #1 is a SQL injection risk. Item #2 is missing rate limiting."
  }
}
```

The `decisionNote` field on the resolved approval contains the human's explanation of their choice.

---

## Budget Tracking

Every agent has a `budgetMonthlyCents` limit. Paperclip tracks API spend for each agent and enforces the limit:

- Each Claude Code run reports token usage
- Usage is converted to cost (cents) based on the model's per-token pricing
- Cumulative monthly spend is maintained per agent
- When an agent hits its budget, new heartbeat runs are skipped (or the run is rejected)
- Budget resets at the start of each calendar month

Budget tracking serves two purposes: cost control (preventing runaway loops) and prioritization (managers can allocate higher budgets to more critical agents).

---

## Adapter Types

The adapter determines how an agent runs. The Engineering Company uses `claude_local` exclusively, but Paperclip supports others:

| Adapter | Description |
|---------|-------------|
| `claude_local` | Runs Claude Code via `claude --print -` on the local machine |
| `codex_local` | Runs OpenAI Codex CLI locally |
| `gemini_local` | Runs Gemini CLI locally |
| `opencode_local` | Runs OpenCode CLI locally |
| `cursor` | Connects to a Cursor IDE instance |
| `openclaw_gateway` | Routes to an OpenClaw gateway server |
| `http` | Generic HTTP endpoint — any agent that speaks the Paperclip HTTP protocol |
| `process` | Runs an arbitrary local process |

The adapter interface is standardized: every adapter receives an `AdapterExecutionContext` (agent config, wake context, auth token) and returns an `AdapterExecutionResult` (outcome, session ID, token usage). Adapters handle skill mounting, prompt construction, and process lifecycle.

---

## Session Continuity

Session continuity is one of Paperclip's most important features. Without it, an agent would lose all context between heartbeats — it would need to re-read the entire codebase, PR, and task history on every wake.

With session continuity:

1. On the first run for a task, the agent starts fresh: `claude --print - ... <prompt>`
2. Claude Code outputs a `sessionId` in its result JSON
3. Paperclip stores this `sessionId` in the `agentTaskSessions` table, linked to the agent + task + cwd
4. On subsequent runs for the same task, Paperclip passes `--resume <sessionId>`
5. Claude Code restores its conversation context: tool call history, read files, prior reasoning
6. The agent continues where it left off

The `--resume` path is only used when the session's `cwd` matches the current run's `cwd`. If the working directory changes (e.g., the agent moves to a different workspace), a new session starts.

Session continuity is especially important for the approval flow. When an agent creates a checkpoint approval and exits, its session is paused but not lost. When Paperclip re-wakes the agent after the human approves, the agent resumes with full context — it knows exactly which step of which skill it was on.

---

## The Wake Context Payload

`PAPERCLIP_WAKE_PAYLOAD_JSON` is a compact JSON summary of the task context injected into every agent run. It is designed to be fast to parse — the agent can read the current task and recent comments without making an API call.

Example payload structure:
```json
{
  "wakeReason": "approval_resolved",
  "task": {
    "id": "issue-uuid",
    "title": "Review the OAuth2 PR",
    "status": "blocked",
    "priority": "high"
  },
  "recentComments": [
    {
      "id": "comment-uuid",
      "body": "Checkpoint: /review ASK items. Approval: <link>",
      "createdAt": "2026-04-04T10:00:00Z"
    }
  ],
  "fallbackFetchNeeded": false
}
```

If `fallbackFetchNeeded` is `true`, the payload was truncated or stale and the agent should call `GET /api/issues/{PAPERCLIP_TASK_ID}` for the full context.

---

## The Checkout Endpoint

`POST /api/issues/{id}/checkout` is the atomic operation that claims an issue for the current run. It prevents duplicate work when multiple heartbeats fire close together or when a previous run is still active.

Behavior:
- `200 OK` with `{ "checked_out": true }` — claim succeeded
- `409 Conflict` with `{ "checked_out": false, "reason": "already_checked_out" }` — another run has it; skip

Agents must always check for `409` and exit cleanly rather than proceeding. Without this, two simultaneous CTO heartbeats could both start reviewing the same PR, doubling the work and potentially creating conflicting commits.

The checkout is automatically released when the run ends (normally or via timeout). It does not need to be manually released.
