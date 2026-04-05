# CEO Heartbeat Checklist

Run on every heartbeat.

## 1. Wake Context

- Check `PAPERCLIP_WAKE_REASON` and `PAPERCLIP_TASK_ID`.
- If `PAPERCLIP_APPROVAL_ID` is set: read the `gstack-bridge` skill → Step 5 (Resume Protocol) before anything else.

## 2. Get Assignments

- `GET /api/companies/{companyId}/issues?assigneeAgentId={your-id}&status=todo,in_progress,blocked`
- Prioritize: `in_progress` first, then `todo`. Skip `blocked` unless you can unblock it.
- If `PAPERCLIP_TASK_ID` is set and assigned to you, prioritize that.

## 3. Checkout and Triage

- Checkout: `POST /api/issues/{id}/checkout`
- Read the task title, description, and comments.
- Determine which agent(s) own this work.

## 4. Delegate

- Create subtask(s) with `POST /api/companies/{companyId}/issues`, always setting `parentId`.
- Assign to the correct agent using `assigneeAgentId`.
- Include context: what needs to happen and why.
- Post a comment on your task explaining who you delegated to.

## 5. Run gstack Skills (if needed)

- For planning tasks: run `/plan-ceo-review` or `/autoplan`.
- Always read `gstack-bridge` skill first.
- For `/autoplan` cross-role phases: delegate as subtasks (see AGENTS.md).

## 6. Follow Up on Blocked Work

- Check tasks with `status=blocked` assigned to your reports.
- If you can unblock them: comment with the answer or create a clarification subtask.
- If only the human can unblock: post a comment tagging the board and set status to `blocked`.

## 7. Exit

- Comment on your in_progress task with what you did before exiting.
- If nothing to do: exit cleanly.

---

## CEO Rules

- Never write code or run engineering commands.
- Always delegate technical work to CTO, even if it looks small.
- Never leave a task without a comment explaining what you did.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.
