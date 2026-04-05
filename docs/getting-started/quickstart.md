# Quickstart

Get the Engineering Company running and create your first task in under 15 minutes.

**Before you start:** Complete [Prerequisites](prerequisites.md). You need Node.js 20+, pnpm 9+, Bun, Claude Code CLI, Git, jq, and an Anthropic API key.

---

## Step 1 — Clone the repository

**Time: ~1 minute**

```bash
git clone <your-repo-url> gstack_paperclip
cd gstack_paperclip
```

You should see three top-level directories:

```
gstack/          # gstack skills framework
paperclip/       # Paperclip orchestration server
companies/       # Company templates
└── engineering/ # The 9-agent engineering team template
```

---

## Step 2 — Install Paperclip dependencies

**Time: ~2 minutes**

```bash
cd paperclip
pnpm install
```

Expected output: pnpm resolves and downloads packages, ending with something like:

```
Progress: resolved 842, reused 820, downloaded 22, added 22, done
```

---

## Step 3 — Start the Paperclip server

**Time: ~30 seconds**

```bash
pnpm dev
```

Expected output:

```
[paperclip] Starting embedded PostgreSQL...
[paperclip] Database ready
[paperclip] Server listening on http://localhost:3100
```

> **Note:** The server uses an embedded PostgreSQL database that starts automatically. No external database configuration is required.

> **Port conflict:** If port 3100 is in use, set `PORT=<other>` in your environment before running `pnpm dev`. Update `PAPERCLIP_URL` in Step 6 accordingly.

Leave this terminal running. Open a new terminal for the remaining steps.

---

## Step 4 — Install gstack dependencies

**Time: ~1 minute**

From the repo root (not inside `paperclip/`):

```bash
cd gstack
bun install
```

Expected output:

```
bun install v1.x.x
  + 12 packages installed
```

gstack does not require a separate build step for the Paperclip integration. The skills are plain directories with SKILL.md files that Paperclip reads directly.

---

## Step 5 — Verify the Paperclip server is running

**Time: ~10 seconds**

```bash
curl -s http://localhost:3100/api/health | jq .
```

Expected output:

```json
{
  "status": "ok",
  "version": "x.x.x"
}
```

If you get `connection refused`, the Paperclip server is not running. Go back to Step 3.

---

## Step 6 — Provision the Engineering Company

**Time: ~1 minute**

```bash
cd ../companies/engineering
./setup.sh
```

Expected output:

```
==> gstack Engineering Company Setup
    Paperclip: http://localhost:3100
    gstack:    /path/to/gstack_paperclip/gstack

--> Step 1: Create company
    Company ID: <uuid>

--> Step 2: Import gstack skills
      + gstack-autoplan
      + gstack-plan-ceo-review
      [... 26 more skills ...]

--> Step 3: Import gstack-bridge skill
      + gstack-bridge

--> Step 4: Create agents
    Created CEO (<uuid>)
    Created CTO (<uuid>)
    Created SeniorEngineer (<uuid>)
    Created ReleaseEngineer (<uuid>)
    Created DevExEngineer (<uuid>)
    Created QALead (<uuid>)
    Created QAEngineer (<uuid>)
    Created SecurityOfficer (<uuid>)
    Created DesignLead (<uuid>)

==> Engineering Company provisioned!

    Company ID: <COMPANY_ID>
    Agents:
      CEO:             <CEO_ID>
      CTO:             <CTO_ID>
      [...]

    Open Paperclip at: http://localhost:3100
    Create an issue to start the team working:
      POST http://localhost:3100/api/companies/<COMPANY_ID>/issues
      {"title": "Your task here", "assigneeAgentId": "<CEO_ID>"}
```

Copy the `COMPANY_ID` and `CEO_ID` values from the output. You will need them in the next step.

> **Custom URL:** If your Paperclip server is on a different port, run:
> ```bash
> PAPERCLIP_URL=http://localhost:4040 ./setup.sh
> ```

---

## Step 7 — Open the Paperclip web UI

**Time: ~10 seconds**

Open your browser to [http://localhost:3100](http://localhost:3100).

You should see the Paperclip dashboard with:
- "Engineering Co" listed under companies
- 9 agents listed in the Agents panel
- An empty Issues board

---

## Step 8 — Create your first task

**Time: ~1 minute**

Replace `<COMPANY_ID>` and `<CEO_ID>` with the values from Step 6 output.

```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/issues \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Add a /health endpoint to the API",
    "description": "We need a GET /health endpoint that returns {status: ok, uptime: <seconds>}. Write the route, add a test, and create a PR.",
    "assigneeAgentId": "<CEO_ID>",
    "priority": "high"
  }'
```

Expected response:

```json
{
  "id": "<ISSUE_ID>",
  "title": "Add a /health endpoint to the API",
  "status": "todo",
  "priority": "high",
  "assigneeAgentId": "<CEO_ID>",
  ...
}
```

You can also create the task through the Paperclip web UI: click **New Issue**, fill in the title and description, and assign it to CEO.

---

## Step 9 — Watch it work

**Time: up to 15 minutes for first heartbeat**

The CEO agent wakes on its heartbeat schedule (`*/15 * * * *` — every 15 minutes). When it does:

1. **CEO wakes** — reads the task, recognizes it as an engineering task, creates subtasks delegating to CTO.
2. **CTO wakes** (up to 20 minutes after CEO) — delegates implementation to SeniorEngineer.
3. **SeniorEngineer wakes** (up to 30 minutes later) — runs `/investigate` and `/codex` to implement the endpoint.

You can watch progress in the Paperclip web UI:
- Click on "Engineering Co" to see the Issues board
- Click the issue to see its comments — agents post progress comments as they work
- Look at the **Activity** tab to see real-time run logs

---

## What Happens at the First Heartbeat

When the CEO wakes for the first time after receiving the task:

1. CEO reads `PAPERCLIP_WAKE_PAYLOAD_JSON` to see the wake context (or calls `GET /api/issues/<task-id>` for full context).
2. CEO reads the `gstack-bridge` skill to understand Paperclip headless mode.
3. CEO identifies the task as an engineering task and decides to delegate to CTO.
4. CEO calls `POST /api/companies/<company-id>/issues` to create a child issue with `parentId` set, `assigneeAgentId` set to CTO's ID, and a description that includes the full context.
5. CEO posts a comment on its own task: "Delegated implementation to CTO as ENG-2."
6. CEO may also run `/plan-ceo-review` if the task needs strategic planning first.
7. CEO exits. The CTO will wake on its own schedule (every 20 minutes) and pick up from there.

---

## Troubleshooting

If setup.sh fails with `connection refused`:
→ Paperclip server is not running. Go to Step 3.

If setup.sh fails with `jq: command not found`:
→ Install jq. See [Prerequisites](prerequisites.md).

If agents do not wake after 30 minutes:
→ Check the Paperclip UI: Agents → click an agent → check "Last run" and any error messages.
→ See [Common Issues](../troubleshooting/common-issues.md).

---

## Next Steps

- [Handle Approvals](../guides/handle-approvals.md) — what to do when an agent needs a human decision
- [Create and Assign Tasks](../guides/create-and-assign-tasks.md) — how to write effective task descriptions
- [Engineering Company](../concepts/engineering-company.md) — understand each agent's role and typical flows
