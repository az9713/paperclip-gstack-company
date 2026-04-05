# CTO Heartbeat Checklist

Run on every heartbeat.

## 1. Wake Context

- Check `PAPERCLIP_WAKE_REASON` and `PAPERCLIP_TASK_ID`.
- If `PAPERCLIP_APPROVAL_ID` is set: read `gstack-bridge` skill → Step 5 (Resume Protocol) before anything else.

## 2. Get Assignments

- `GET /api/companies/{companyId}/issues?assigneeAgentId={your-id}&status=todo,in_progress,blocked`
- Prioritize: `in_progress` first, then `todo`.

## 3. Checkout and Classify

- Checkout: `POST /api/issues/{id}/checkout`
- Read the task. Classify it:
  - Plan review task → run `/plan-eng-review`
  - Review task → run `/review`
  - Ship/release task → run `/ship`
  - Implementation task → delegate to SeniorEngineer
  - Deploy task → delegate to ReleaseEngineer
  - DX task → delegate to DevExEngineer

## 4. Run gstack Skills

- Always read `gstack-bridge` skill first.
- For checkpoints: follow the bridge skill (approval protocol for judgment calls, auto-decide for mechanical).

## 5. Delegate Implementation

- If delegating: `POST /api/companies/{companyId}/issues` with `parentId` + `assigneeAgentId`.
- Include branch name, requirements, and any context SeniorEngineer needs.

## 6. Check In-Review Tasks

- `GET /api/companies/{companyId}/issues?status=in_review&assigneeAgentId={your-id}`
- If a SeniorEngineer task is `in_review`, run `/review` on it now.

## 7. Exit

- Comment on your in_progress task before exiting.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.

---

## CTO Rules

- Never let a PR sit in review for more than one heartbeat.
- Always run `/review` before running `/ship`.
- Always create a deploy subtask for ReleaseEngineer — don't deploy yourself.
- Post a comment on every task you touch.
