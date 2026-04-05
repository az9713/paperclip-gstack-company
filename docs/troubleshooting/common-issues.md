# Common Issues

The ten most common problems and their fixes.

---

## 1. Paperclip server not starting — port conflict

**Symptom:** `pnpm dev` exits with `EADDRINUSE` or `Error: listen EADDRINUSE :::3100`.

**Cause:** Another process is already using port 3100.

**Fix:**

Find and stop the conflicting process:
```bash
# macOS / Linux
lsof -ti :3100 | xargs kill -9

# Windows
netstat -ano | findstr :3100
taskkill /PID <pid> /F
```

Or run Paperclip on a different port:
```bash
PORT=3200 pnpm dev
```

If you change the port, update `PAPERCLIP_URL` in any scripts you use:
```bash
PAPERCLIP_URL=http://localhost:3200 ./setup.sh
```

---

## 2. Paperclip server not starting — database issue

**Symptom:** Server starts, then crashes with a PostgreSQL error like `FATAL: role "postgres" does not exist` or `Error: could not connect to server`.

**Cause:** The embedded PostgreSQL process failed to start, or a leftover database process is conflicting.

**Fix:**

Stop any leftover PostgreSQL processes:
```bash
# macOS
pkill -f "postgres.*paperclip"

# Linux
pkill -f "postgres.*paperclip"
```

Delete the embedded database data directory and let it recreate:
```bash
# Find the database directory (check paperclip .env or logs for DB_DATA_DIR)
# Typical location:
rm -rf ~/.paperclip/data/db
```

Then restart:
```bash
cd paperclip && pnpm dev
```

If the error persists, check the full startup log for the exact PostgreSQL error message and look up that specific error.

---

## 3. setup.sh fails — Paperclip not running

**Symptom:** `./setup.sh` fails immediately with `curl: (7) Failed to connect to localhost port 3100`.

**Cause:** The Paperclip server is not running.

**Fix:**

Start the server in a separate terminal:
```bash
cd paperclip && pnpm dev
```

Wait for `Server listening on http://localhost:3100` before running setup.sh again.

---

## 4. setup.sh fails — jq not installed

**Symptom:** `./setup.sh` fails with `jq: command not found`.

**Fix:**

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows
winget install jqlang.jq
```

---

## 5. Agent not waking — heartbeat not firing

**Symptom:** Tasks are assigned to an agent but it never picks them up. The agent shows no recent runs in the UI.

**Causes and fixes:**

**Cause A: Company or agent is paused**
→ Open the Paperclip UI → Agents → click the agent → check its status. If it shows "paused", re-activate it.

**Cause B: No tasks assigned**
→ The agent's inbox may be empty. Check: does the task have the correct `assigneeAgentId`? Verify by calling `GET /api/companies/{id}/issues?assigneeAgentId={agentId}&status=todo`.

**Cause C: Budget exhausted**
→ Check the agent's budget usage in the UI. If it has hit its monthly limit, runs are blocked until the month resets.

**Cause D: Heartbeat schedule misconfigured**
→ Check the agent's `heartbeat.schedule` value. An invalid cron expression silently prevents scheduling. Use [crontab.guru](https://crontab.guru) to validate your expression.

**Cause E: Agent is paused by an error in a previous run**
→ Check the agent's run history in the UI for error states. If a previous run crashed, the agent may be in an error state. Check logs and re-activate.

---

## 6. Approval not working — `gstack_checkpoint` type not registered

**Symptom:** Agent fails when calling `POST /api/companies/{id}/approvals` with `type: "gstack_checkpoint"`. Error: `400 Bad Request: invalid approval type`.

**Cause:** The `gstack_checkpoint` approval type is defined in `paperclip/packages/shared/src/constants.ts`. If you are running an older version of Paperclip that predates this addition, the type will be rejected.

**Fix:**

Verify the type is registered:
```bash
grep -r "gstack_checkpoint" paperclip/packages/shared/src/
```

If not found, add it to the `APPROVAL_TYPES` array in `paperclip/packages/shared/src/constants.ts`:
```typescript
export const APPROVAL_TYPES = [
  "hire_agent",
  "approve_ceo_strategy",
  "budget_override_required",
  "gstack_checkpoint",  // Add this
] as const;
```

Then rebuild and restart:
```bash
cd paperclip && pnpm build && pnpm dev
```

---

## 7. Agent calls `AskUserQuestion` anyway

**Symptom:** An agent run fails or hangs because it called `AskUserQuestion` in headless Paperclip mode. You see in the run logs: `Tool AskUserQuestion called but no stdin available`.

**Cause:** The `gstack-bridge` skill was not read by the agent before running the gstack skill, or the agent did not follow its instructions.

**Fix:**

**Step 1:** Verify the bridge skill is in the agent's desired skills:
```bash
curl -s http://localhost:3100/api/agents/<AGENT_ID>/skills | \
  jq '.entries[] | select(.key == "gstack-bridge")'
```

If it shows `state: "missing"`, the bridge skill was not imported. Import it:
```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/skills/import \
  -H "Content-Type: application/json" \
  -d '{"source": "/absolute/path/to/companies/engineering/skills/gstack-bridge"}'
```

**Step 2:** Verify the agent's task description explicitly mentions the bridge skill. Add to the task description:
```
Read the gstack-bridge skill FIRST before invoking any gstack skill.
```

**Step 3:** If the issue persists, check the agent's onboarding bundle (AGENTS.md) — it should include:
```
Read the `gstack-bridge` skill before invoking any gstack skill.
```

---

## 8. Skill import fails — path not found

**Symptom:** `POST /api/companies/{id}/skills/import` returns `400` or `404` with an error about the source path not being found.

**Cause:** The `source` path in the import request is not an absolute path, the directory does not exist, or the directory does not contain a `SKILL.md` file.

**Fix:**

Ensure the path is absolute:
```bash
# This will fail:
{"source": "../../gstack/review"}

# This will work:
{"source": "/absolute/path/to/gstack/review"}
```

Verify the skill directory exists and has a SKILL.md:
```bash
ls /absolute/path/to/gstack/review/SKILL.md
```

If you are running setup.sh and it is failing on skill imports, check the `GSTACK_DIR` variable in the script:
```bash
GSTACK_DIR="$(cd "${SCRIPT_DIR}/../../gstack" && pwd)"
echo "gstack dir: ${GSTACK_DIR}"
ls "${GSTACK_DIR}"
```

If this fails, the gstack directory is not at the expected relative path from `companies/engineering/`.

---

## 9. Session resume fails — session expired

**Symptom:** An agent's run log shows `[paperclip] Claude session "xyz" was saved for cwd "..." and will not be resumed` or `session not found` error from Claude.

**Cause:** Claude Code sessions expire after a period of inactivity. When `--resume <sessionId>` is passed for an expired session, Claude Code cannot restore the context.

**What happens:** Paperclip detects the session error and falls back to starting a new session. The agent starts fresh but still has access to the task context via the Paperclip API — it reads the task title, description, and comments to reconstruct context.

**Impact:** The agent may need to re-read files it already read. For long-running tasks, this can add a few extra API calls. It does not cause data loss or task failure.

**If fallback is not working:** Verify that `isClaudeUnknownSessionError` in the adapter handles the specific error message Claude returns for expired sessions. Check `paperclip/packages/adapters/claude-local/src/server/parse.ts`.

---

## 10. Agent exceeds `maxTurnsPerRun`

**Symptom:** Agent run logs show `Max turns reached` and the task is still in progress. The agent exits before completing its work.

**Cause:** The task requires more Claude Code turns than the agent's `maxTurnsPerRun` configuration allows.

**What happens:** The run exits cleanly. Paperclip records the session ID. On the next heartbeat, the agent resumes with `--resume` and continues from where it left off, with a fresh turn budget.

**If the task is never completing:** The agent may be in a loop, spending all its turns without making progress.

Check the agent's run logs for repeated patterns. Common loops:
- Reading the same files repeatedly (missing the information)
- Failing tests that prevent moving forward
- Missing tool permissions (the agent keeps trying a command that fails)

**Fix options:**

Increase `maxTurnsPerRun` if the task is genuinely large and not a loop:
```bash
curl -X PATCH http://localhost:3100/api/agents/<AGENT_ID> \
  -H "Content-Type: application/json" \
  -d '{"adapterConfig": {"maxTurnsPerRun": 300}}'
```

If the agent is looping, add context to the task as a comment:
```bash
curl -X POST http://localhost:3100/api/issues/<ISSUE_ID>/comments \
  -H "Content-Type: application/json" \
  -d '{"body": "Note: The tests are expected to fail on the current main branch (known issue). Proceed with the fix even if tests fail."}'
```

---

## Known Pre-Existing Issue: drizzle-orm ESM Cycle

**Symptom:** Running `pnpm test:run` in the Paperclip monorepo fails with 54 tests crashing due to a circular dependency error involving `drizzle-orm`:

```
Error: Cannot access 'eq' before initialization
    at packages/db/src/...
```

**Cause:** This is a known pre-existing issue in the `packages/db` tests related to an ESM circular dependency in `drizzle-orm`. It is not caused by any code change in this repository.

**Impact:** Only the 54 database-dependent tests in `packages/db` are affected. The server, UI, CLI, and adapter tests all pass. The running Paperclip server is not affected.

**Fix:** This requires a fix upstream in `drizzle-orm` or a structural change to how the db package imports are ordered. Until then, run the non-db test suite:

```bash
cd paperclip
pnpm test:run --project server --project ui --project cli
```

Do not treat this as a failure introduced by your changes unless the number of failing tests increases beyond 54.
