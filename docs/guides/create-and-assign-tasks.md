# Create and Assign Tasks

How to create tasks (issues) for the Engineering Company, write effective descriptions, understand task hierarchy, and track progress.

---

## Create a Task via the Web UI

1. Open [http://localhost:3100](http://localhost:3100)
2. Navigate to your company (Engineering Co)
3. Click **New Issue** in the Issues panel
4. Fill in:
   - **Title** — short, specific, actionable (see "What Makes a Good Task" below)
   - **Description** — context, constraints, acceptance criteria
   - **Assignee** — select "CEO" for most tasks; the CEO routes to specialists
   - **Priority** — `critical`, `high`, `medium`, or `low`
5. Click **Create**

The task appears in the Issues board immediately. The CEO will pick it up on its next heartbeat (within 15 minutes).

---

## Create a Task via API

Replace `<COMPANY_ID>` and `<CEO_ID>` with values from your setup:

```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/issues \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Add rate limiting to the /api/auth/login endpoint",
    "description": "The login endpoint currently has no rate limiting. Add a limit of 5 attempts per IP per 15 minutes. Return 429 with Retry-After header when exceeded. Add integration tests.",
    "assigneeAgentId": "<CEO_ID>",
    "priority": "high"
  }'
```

Response:
```json
{
  "id": "<ISSUE_ID>",
  "identifier": "ENG-7",
  "title": "Add rate limiting to the /api/auth/login endpoint",
  "status": "todo",
  "priority": "high",
  "assigneeAgentId": "<CEO_ID>",
  "createdAt": "2026-04-04T10:00:00Z"
}
```

---

## What Makes a Good Task

The quality of your task description directly affects the quality of the agent's output. Agents work from the text you provide — vague tasks produce vague results.

### Good task title patterns

- Specific and actionable: "Add rate limiting to /api/auth/login"
- Bug-style: "Bug: login form shows blank screen on invalid email"
- Planning-style: "Plan: new user onboarding redesign"
- Explicit command: "Run /cso security audit on the payments module"

### Poor task title patterns

- Too vague: "Improve the login page"
- No action: "Auth"
- Too broad: "Fix all the bugs"

### What to include in the description

**Acceptance criteria** — what does "done" look like?

```
Rate limiting should:
- Limit to 5 attempts per IP per 15 minutes
- Return 429 with `Retry-After` header
- Not affect other endpoints
- Have integration tests
```

**Constraints** — what are the non-negotiable requirements?

```
- Must use Redis for state (not in-memory)
- Must not break existing auth tests
- PR must be under 200 lines changed
```

**Context** — what does the agent need to know that is not obvious from the codebase?

```
The auth module is in src/api/auth/. We use express-rate-limit for other rate limiting.
Check src/api/middleware/rateLimiter.ts for the existing pattern.
```

**Explicit skill invocation** — if you want a specific gstack skill, say so:

```
Run /investigate to find the root cause before writing any fix.
Run /cso to check for other auth security issues while you are in the auth module.
```

**Pre-answered checkpoints** — if you already know the answers to likely approval questions:

```
Use MINOR version bump (this adds a new API behavior).
If review finds any security issues: fix them all inline, do not defer.
```

---

## Understanding Task Hierarchy

Tasks can be nested. A parent task represents a larger goal; child tasks are delegated work.

### Parent-child relationships

When you create a top-level task, the CEO creates child tasks for each specialist:

```
ENG-1: "Build user auth with OAuth2"  [CEO, in_review]
  ├── ENG-2: "Implement auth backend"  [SeniorEngineer, in_review]
  │     ├── ENG-5: "Review auth PR"    [CTO, done]
  │     └── ENG-6: "Deploy auth"       [ReleaseEngineer, done]
  ├── ENG-3: "Security audit of auth"  [SecurityOfficer, done]
  └── ENG-4: "Design login page UI"   [DesignLead, in_review]
```

To create a task that is explicitly a child of another:

```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/issues \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Fix SQL injection in auth middleware",
    "parentId": "<PARENT_ISSUE_ID>",
    "assigneeAgentId": "<SENIOR_ENG_ID>",
    "priority": "critical"
  }'
```

### Goal alignment (goalId)

Tasks can be linked to higher-level company goals via `goalId`. This provides agents with the "why" behind the task — it appears in their context when they read the task.

Goals are created via `POST /api/companies/{id}/goals`. Linking a task to a goal is not required but helps agents make better decisions about scope and priority.

---

## Check Task Status

### Via Web UI

Open the Issues board in the Paperclip UI. Tasks are grouped by status column (Todo, In Progress, In Review, Done, Blocked). Click any task to see its comment thread, which shows agent activity.

### Via API

```bash
# Get a specific issue
curl -s http://localhost:3100/api/issues/<ISSUE_ID> | jq '{title, status, assigneeAgentId}'

# List all issues for a company
curl -s "http://localhost:3100/api/companies/<COMPANY_ID>/issues" | jq '[.[] | {identifier, title, status}]'

# Filter by status
curl -s "http://localhost:3100/api/companies/<COMPANY_ID>/issues?status=in_progress,blocked" | jq '.[] | .title'
```

### Understanding What "Blocked" Means

When a task shows status `blocked`, it means an agent is waiting for a human decision. Check the task's comments — the agent will have posted a checkpoint question explaining what it is waiting for. Go to the Approvals panel to find and resolve the pending approval.

See [Handle Approvals](handle-approvals.md) for the full flow.

---

## Comment on a Task

Agents read task comments as part of their context. You can use comments to provide additional information, answer anticipated approval questions upfront, or redirect the agent:

```bash
curl -X POST http://localhost:3100/api/issues/<ISSUE_ID>/comments \
  -H "Content-Type: application/json" \
  -d '{
    "body": "Additional context: the rate limiting library is already installed (express-rate-limit). Use the existing pattern in src/api/middleware/rateLimiter.ts. For the version bump: use PATCH since this is adding to an existing feature without breaking changes."
  }'
```

> **Tip:** If you comment after a task has started (but before a checkpoint), the agent will read your comment on its next wake and may be able to proceed without needing an approval.

---

## Assign to a Specialist Directly

You do not have to assign everything to the CEO. If you know exactly which specialist should handle the work, assign it directly:

```bash
# Assign a security audit directly to SecurityOfficer
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/issues \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Run OWASP security audit on the payments module",
    "description": "Run /cso on src/payments/. Focus on input validation and authorization checks.",
    "assigneeAgentId": "<SECURITY_OFFICER_ID>",
    "priority": "high"
  }'
```

Direct assignment skips the CEO routing delay but requires you to know the correct specialist for the task.
