# Environment Variables

Every environment variable Paperclip injects into agent runs. Variables are set by the `claude_local` adapter before invoking Claude Code.

---

## Core Identity Variables

These five variables are present in every Paperclip run. The `gstack-bridge` skill checks for all five to confirm it is in Paperclip mode.

| Variable | When Set | Description | Example |
|----------|----------|-------------|---------|
| `PAPERCLIP_AGENT_ID` | Every run | UUID of the agent executing this run | `"a1b2c3d4-..."` |
| `PAPERCLIP_COMPANY_ID` | Every run | UUID of the company this agent belongs to | `"e5f6g7h8-..."` |
| `PAPERCLIP_API_URL` | Every run | Base URL of the Paperclip API server | `"http://localhost:3100"` |
| `PAPERCLIP_API_KEY` | Every run | Bearer token for authenticating API calls | `"pclip_..."` |
| `PAPERCLIP_RUN_ID` | Every run | UUID of the current run. Include as `X-Paperclip-Run-Id` header on mutating API calls for audit tracing. | `"run-uuid-..."` |

**Bridge skill usage:** All five are checked in Step 0 to confirm Paperclip mode. If all five are present, all bridge skill rules apply.

---

## Task Context Variables

Set when the agent is woken with a specific task to work on.

| Variable | When Set | Description | Example |
|----------|----------|-------------|---------|
| `PAPERCLIP_TASK_ID` | When woken for a task | UUID of the issue/task to work on. Use in all issue API calls. | `"issue-uuid-..."` |
| `PAPERCLIP_WAKE_REASON` | When woken | Why the agent was woken. See wake reasons table below. | `"approval_resolved"` |
| `PAPERCLIP_WAKE_PAYLOAD_JSON` | When wake payload is available | Compact JSON with task summary, recent comments, and wake reason. Avoids an API round-trip to get task context. | See below |
| `PAPERCLIP_WAKE_COMMENT_ID` | When woken by a comment | UUID of the comment that triggered the wake | `"comment-uuid-..."` |

**Wake reasons:**

| Value | Meaning | Bridge skill action |
|-------|---------|-------------------|
| `heartbeat` | Regular scheduled wake | Check inbox, pick up todo/in_progress tasks |
| `task_assigned` | A task was just assigned to this agent | Work the newly assigned task |
| `approval_resolved` | A human just resolved one of this agent's approvals | Jump to Resume Protocol — check `PAPERCLIP_APPROVAL_ID` |
| `comment_added` | A comment was added to an assigned task | Read the comment, may need to respond or unblock |
| `subtask_completed` | A subtask this agent created is now done | Pick up the parent task and continue |

**`PAPERCLIP_WAKE_PAYLOAD_JSON` example:**
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
      "body": "## gstack checkpoint: review/ASK items\n\n...",
      "createdAt": "2026-04-04T10:00:00Z"
    }
  ],
  "fallbackFetchNeeded": false
}
```

If `fallbackFetchNeeded` is `true`, call `GET /api/issues/{PAPERCLIP_TASK_ID}` for the full context.

---

## Approval Variables

Set when the agent is woken to handle an approval resolution.

| Variable | When Set | Description | Example |
|----------|----------|-------------|---------|
| `PAPERCLIP_APPROVAL_ID` | When an approval was resolved | UUID of the resolved approval. Triggers the Resume Protocol in the bridge skill. | `"approval-uuid-..."` |
| `PAPERCLIP_APPROVAL_STATUS` | When an approval was resolved | The resolution status of the approval | `"approved"`, `"rejected"`, `"revision_requested"` |

**Bridge skill usage:** When `PAPERCLIP_APPROVAL_ID` is set, the bridge skill immediately goes to Step 5 (Resume Protocol) instead of the normal heartbeat flow. The agent fetches the approval, reads the human's decision, and continues the interrupted gstack skill.

---

## Session Variables

Managed by the Paperclip runtime to support session continuity.

> **Note:** These are used internally by the `claude_local` adapter. The bridge skill does not directly reference them — `--resume <sessionId>` is passed as a CLI argument, not an environment variable.

The session ID is extracted from Claude's output JSON after each run and stored in the `agentTaskSessions` table. On subsequent runs for the same task + cwd, Paperclip passes `--resume <sessionId>` as a CLI argument. This is transparent to the bridge skill — the agent simply has its full prior context available.

---

## Workspace Variables

Set when a workspace (git worktree, remote repository, etc.) is configured for the agent.

| Variable | When Set | Description | Example |
|----------|----------|-------------|---------|
| `PAPERCLIP_WORKSPACE_CWD` | When workspace has a cwd | The working directory for this workspace | `"/home/user/projects/myapp"` |
| `PAPERCLIP_WORKSPACE_SOURCE` | When workspace is active | How the workspace was sourced | `"git_worktree"`, `"agent_home"` |
| `PAPERCLIP_WORKSPACE_STRATEGY` | When workspace is active | The workspace strategy in use | `"git_worktree"` |
| `PAPERCLIP_WORKSPACE_ID` | When workspace has an ID | UUID of the workspace | `"ws-uuid-..."` |
| `PAPERCLIP_WORKSPACE_REPO_URL` | When workspace has a repo | Repository URL | `"https://github.com/org/repo"` |
| `PAPERCLIP_WORKSPACE_REPO_REF` | When workspace has a ref | Git ref (branch, commit, tag) | `"main"`, `"feature/auth"` |
| `PAPERCLIP_WORKSPACE_BRANCH` | When workspace has a branch | Current branch name | `"feature/auth"` |
| `PAPERCLIP_WORKSPACE_WORKTREE_PATH` | When using git worktree | Absolute path to the worktree | `"/tmp/worktrees/feature-auth"` |
| `AGENT_HOME` | When workspace sets agent home | Home directory for this agent run | `"/home/paperclip/agents/cto"` |
| `PAPERCLIP_WORKSPACES_JSON` | When multiple workspaces exist | JSON array of workspace hint objects | `[{"id": ..., "cwd": ...}]` |

---

## Runtime Service Variables

Set when the agent has associated runtime services (databases, dev servers, etc.).

| Variable | When Set | Description | Example |
|----------|----------|-------------|---------|
| `PAPERCLIP_RUNTIME_SERVICES_JSON` | When services are running | JSON array of active runtime service records | See Paperclip docs |
| `PAPERCLIP_RUNTIME_SERVICE_INTENTS_JSON` | When service intents exist | JSON array of service intent declarations | See Paperclip docs |
| `PAPERCLIP_RUNTIME_PRIMARY_URL` | When primary service has a URL | URL of the primary runtime service | `"http://localhost:4000"` |

---

## Linked Issue Variables

| Variable | When Set | Description | Example |
|----------|----------|-------------|---------|
| `PAPERCLIP_LINKED_ISSUE_IDS` | When the wake context includes linked issues | Comma-separated UUIDs of issues linked to the wake context | `"uuid1,uuid2,uuid3"` |

---

## How the Bridge Skill Uses These Variables

The bridge skill explicitly references these variables in its protocol steps:

| Protocol step | Variables used |
|--------------|---------------|
| Confirm Paperclip mode | `PAPERCLIP_AGENT_ID`, `PAPERCLIP_COMPANY_ID`, `PAPERCLIP_API_URL`, `PAPERCLIP_API_KEY`, `PAPERCLIP_RUN_ID` |
| Identify task | `PAPERCLIP_WAKE_PAYLOAD_JSON`, `PAPERCLIP_TASK_ID`, `PAPERCLIP_APPROVAL_ID` |
| Create approval | `PAPERCLIP_COMPANY_ID`, `PAPERCLIP_AGENT_ID`, `PAPERCLIP_API_KEY`, `PAPERCLIP_RUN_ID` |
| Post comment | `PAPERCLIP_TASK_ID`, `PAPERCLIP_RUN_ID`, `PAPERCLIP_API_URL` |
| Block issue | `PAPERCLIP_TASK_ID`, `PAPERCLIP_RUN_ID` |
| Resume: fetch approval | `PAPERCLIP_APPROVAL_ID`, `PAPERCLIP_API_KEY` |
| Resume: unblock issue | `PAPERCLIP_TASK_ID`, `PAPERCLIP_RUN_ID` |
| Create delegation subtask | `PAPERCLIP_COMPANY_ID`, `PAPERCLIP_TASK_ID`, `PAPERCLIP_RUN_ID` |
