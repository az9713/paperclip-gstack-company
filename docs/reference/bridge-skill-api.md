# Bridge Skill API Reference

Every API call the `gstack-bridge` skill makes, with endpoint, method, required headers, request body schema, response schema, and error cases.

All API calls use:
- Base URL: `$PAPERCLIP_API_URL` (e.g., `http://localhost:3100`)
- Auth: `Authorization: Bearer $PAPERCLIP_API_KEY`
- Content-Type: `application/json` for all POST/PATCH requests
- Run tracing: `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID` on all mutating requests

---

## Read Current Task

Used in Step 1 when `PAPERCLIP_WAKE_PAYLOAD_JSON` is absent or stale.

```
GET /api/issues/{issueId}
```

**Path params:**
| Param | Value |
|-------|-------|
| `issueId` | `$PAPERCLIP_TASK_ID` |

**Response:**
```json
{
  "id": "uuid",
  "identifier": "ENG-7",
  "title": "...",
  "description": "...",
  "status": "in_progress",
  "priority": "high",
  "assigneeAgentId": "uuid",
  "parentId": "uuid | null",
  "goalId": "uuid | null",
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601"
}
```

**Errors:**
- `404 Not Found` — issue does not exist or does not belong to the agent's company

---

## Checkout an Issue

Must be called before working any issue. Prevents duplicate work.

```
POST /api/issues/{issueId}/checkout
```

**Path params:**
| Param | Value |
|-------|-------|
| `issueId` | The issue ID to claim |

**Headers:** `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID`

**Request body:** empty

**Response (200 — checkout succeeded):**
```json
{ "checked_out": true }
```

**Response (409 — already checked out):**
```json
{
  "checked_out": false,
  "reason": "already_checked_out"
}
```

**Action on 409:** Skip the issue and move to the next one. Do not proceed with work.

---

## Create an Approval

Used in Step 4a of the Approval Protocol when a judgment checkpoint is reached.

```
POST /api/companies/{companyId}/approvals
```

**Path params:**
| Param | Value |
|-------|-------|
| `companyId` | `$PAPERCLIP_COMPANY_ID` |

**Headers:** `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID`

**Request body:**
```json
{
  "type": "gstack_checkpoint",
  "requestedByAgentId": "{PAPERCLIP_AGENT_ID}",
  "payload": {
    "skill": "review",
    "step": "ASK items",
    "question": "Found 2 judgment-call items. How should we proceed?",
    "options": [
      { "key": "A", "label": "Fix both items inline" },
      { "key": "B", "label": "Fix #1 only, defer #2" },
      { "key": "C", "label": "Defer both items" }
    ],
    "recommendation": "A",
    "context": "Item #1 is a SQL injection risk. Item #2 is missing rate limiting."
  }
}
```

**Request body fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `"gstack_checkpoint"` |
| `requestedByAgentId` | string | Yes | The agent's UUID (`$PAPERCLIP_AGENT_ID`) |
| `payload.skill` | string | Yes | The gstack skill name (e.g., `"review"`, `"land-and-deploy"`) |
| `payload.step` | string | Yes | The specific step name from the skill |
| `payload.question` | string | Yes | The question being asked, in plain English |
| `payload.options` | array | Yes | 2-4 options. Each has `key` (letter) and `label` (description) |
| `payload.recommendation` | string | Yes | The agent's recommended option key (e.g., `"A"`) |
| `payload.context` | string | Yes | Why this decision matters — what the human needs to know |

**Response:**
```json
{
  "id": "approval-uuid",
  "type": "gstack_checkpoint",
  "status": "pending",
  "requestedByAgentId": "agent-uuid",
  "payload": { ... },
  "createdAt": "ISO8601"
}
```

**Errors:**
- `400 Bad Request` — missing required fields, invalid type, or invalid option keys
- `403 Forbidden` — `requestedByAgentId` does not match the authenticated agent

---

## Link Approval to Issue

Used in Step 4b. Creates the association shown in the issue detail view.

```
POST /api/approvals/{approvalId}/issues
```

**Path params:**
| Param | Value |
|-------|-------|
| `approvalId` | The UUID returned from Create Approval |

**Request body:**
```json
{ "issueId": "{PAPERCLIP_TASK_ID}" }
```

**Response:**
```json
{ "linked": true }
```

**Errors:**
- `404 Not Found` — approval or issue does not exist
- `409 Conflict` — approval is already linked to this issue

---

## Post Issue Comment

Used in Step 4c. Posts the formatted checkpoint question to the issue thread.

```
POST /api/issues/{issueId}/comments
```

**Path params:**
| Param | Value |
|-------|-------|
| `issueId` | `$PAPERCLIP_TASK_ID` |

**Headers:** `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID`

**Request body:**
```json
{
  "body": "## gstack checkpoint: review/ASK items\n\nFound 2 judgment-call items. How should we proceed?\n\n**Options:**\n- A) Fix both items inline\n- B) Fix #1 only, defer #2\n- C) Defer both items\n\n**Recommendation:** A — Item #1 is a SQL injection risk.\n\nApproval: [View](http://localhost:3100/approvals/approval-uuid)"
}
```

**Request body fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `body` | string | Yes | Markdown-formatted comment body. Include the skill/step in a heading, the question, options as a list, recommendation, and a link to the approval. |

**Response:**
```json
{
  "id": "comment-uuid",
  "body": "...",
  "createdAt": "ISO8601"
}
```

---

## Patch Issue Status

Used in Step 4d (block) and Step 5d (unblock). Also used to mark tasks as `in_review` when delegating.

```
PATCH /api/issues/{issueId}
```

**Path params:**
| Param | Value |
|-------|-------|
| `issueId` | `$PAPERCLIP_TASK_ID` |

**Headers:** `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID`

**Request body (block):**
```json
{
  "status": "blocked",
  "comment": "Waiting for human decision on review checkpoint: ASK items. See approval."
}
```

**Request body (unblock):**
```json
{ "status": "in_progress" }
```

**Request body (mark in_review for delegation):**
```json
{
  "status": "in_review",
  "comment": "Delegated to DesignLead (ENG-15). Waiting for design review."
}
```

**Updatable fields:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | New status. One of: `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled` |
| `comment` | string | Optional comment to post alongside the status change |
| `title` | string | Update issue title |
| `description` | string | Update issue description |
| `priority` | string | Update priority: `critical`, `high`, `medium`, `low` |
| `assigneeAgentId` | string | Reassign to another agent |

**Response:** the updated issue object (same schema as GET /api/issues/{id})

---

## Fetch Approval (Resume Protocol)

Used in Step 5a when the agent is woken with `PAPERCLIP_APPROVAL_ID` set.

```
GET /api/approvals/{approvalId}
```

**Path params:**
| Param | Value |
|-------|-------|
| `approvalId` | `$PAPERCLIP_APPROVAL_ID` |

**Response:**
```json
{
  "id": "approval-uuid",
  "type": "gstack_checkpoint",
  "status": "approved",
  "requestedByAgentId": "agent-uuid",
  "resolvedAt": "ISO8601",
  "decisionNote": "Option B. Fix the SQL injection now — rate limiting can wait.",
  "payload": {
    "skill": "review",
    "step": "ASK items",
    "question": "...",
    "options": [...],
    "recommendation": "A",
    "context": "..."
  }
}
```

**Key fields for the Resume Protocol:**

| Field | What to do with it |
|-------|-------------------|
| `status: "approved"` | Continue the skill. Read `decisionNote` for which option was chosen. |
| `status: "rejected"` | Stop work. Post a comment explaining, close the task. |
| `status: "revision_requested"` | Apply the changes described in `decisionNote`, then continue. |
| `decisionNote` | The human's explanation. May contain: option letter (e.g., "Option B"), additional context, or requested changes. |

---

## Create Delegation Subtask

Used in Step 6 of the Delegation Protocol when a cross-role phase is needed.

```
POST /api/companies/{companyId}/issues
```

**Path params:**
| Param | Value |
|-------|-------|
| `companyId` | `$PAPERCLIP_COMPANY_ID` |

**Headers:** `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID`

**Request body:**
```json
{
  "title": "Design review: Plan for user onboarding redesign",
  "description": "Context from parent task ENG-3:\n\nWe are planning a complete redesign of the user onboarding flow. Please run /plan-design-review on the attached plan document and post your findings.\n\nParent task: ENG-3 — Plan user onboarding redesign",
  "parentId": "{PAPERCLIP_TASK_ID}",
  "assigneeAgentId": "<design-lead-agent-id>",
  "status": "todo",
  "priority": "high"
}
```

**Request body fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Clear, specific task title |
| `description` | string | Yes | Full context from the parent task. Include what needs to happen and why. |
| `parentId` | string | Yes | The current task's ID — creates the parent-child relationship |
| `assigneeAgentId` | string | Yes | The target agent's UUID |
| `status` | string | No | Default `"todo"` |
| `priority` | string | No | Default `"medium"`. Use `"high"` for delegation subtasks. |
| `goalId` | string | No | Inherit from parent task if available |

**Response:** the created issue object

---

## List Issues (Inbox Check)

Used in heartbeat HEARTBEAT.md flows to find pending work.

```
GET /api/companies/{companyId}/issues
```

**Query params:**

| Param | Description | Example |
|-------|-------------|---------|
| `assigneeAgentId` | Filter by assignee | `$PAPERCLIP_AGENT_ID` |
| `status` | Comma-separated statuses | `todo,in_progress,blocked` |
| `priority` | Filter by priority | `critical,high` |
| `parentId` | Filter by parent | Parent issue UUID |

**Example — get my pending work:**
```
GET /api/companies/{companyId}/issues?assigneeAgentId={agentId}&status=todo,in_progress
```

**Response:**
```json
[
  {
    "id": "uuid",
    "identifier": "ENG-7",
    "title": "...",
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": "uuid",
    "parentId": "uuid | null"
  }
]
```
