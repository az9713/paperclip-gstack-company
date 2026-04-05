# Add a New Agent

How to add a custom agent to the Engineering Company: pick a role, choose skills, write onboarding documents, register the agent, and verify it is working.

---

## Decide the Agent's Role

Before creating the agent, define:

1. **What is this agent responsible for?** (Narrow, specific roles work better than broad ones)
2. **Who does it report to?** (CEO for department heads; CTO/QALead/etc. for specialists)
3. **What gstack skills does it need?** (2-5 skills is the right range)
4. **How often should it wake?** (Calibrate to work urgency and cost)

Example: adding a "Data Engineer" who analyzes production data and creates reports.

- **Role:** `ic` (individual contributor)
- **Reports to:** CTO
- **Skills:** `/investigate` (for data investigation), a custom `/data-analysis` skill you will create
- **Heartbeat:** every 2 hours (not urgent)

---

## Choose gstack Skills

Assign skills from this list (all are already imported into the Engineering Company):

| Skill key | What it does |
|-----------|-------------|
| `gstack-investigate` | Root-cause debugging |
| `gstack-codex` | Multi-AI second opinion |
| `gstack-review` | Code review |
| `gstack-ship` | Version bump + PR creation |
| `gstack-qa` | Full QA loop |
| `gstack-qa-only` | Report-only QA |
| `gstack-cso` | Security audit |
| `gstack-careful` | Careful mode |
| `gstack-benchmark` | Performance benchmarking |
| `gstack-retro` | Retrospective |
| `gstack-devex-review` | DX audit |
| `gstack-land-and-deploy` | Deploy pipeline |
| `gstack-canary` | Post-deploy monitoring |
| `gstack-document-release` | Release documentation |
| `gstack-design-review` | Design audit |
| `gstack-design-html` | Design to HTML |

Always include:
- `paperclip` — the Paperclip API skill (teaches the agent how to interact with Paperclip)
- `gstack-bridge` — the bridge skill (required for headless gstack operation)

---

## Write the Onboarding Bundle

Create a directory at `companies/engineering/onboarding/<agent-key>/`. Replace `<agent-key>` with a kebab-case identifier (e.g., `data-engineer`).

### AGENTS.md (required)

Defines the agent's role, skills, delegation rules, and references:

```markdown
# Data Engineer

You are the Data Engineer. You analyze production data, generate insights reports, and flag anomalies to the CTO.

Your home directory is $AGENT_HOME.

## Your gstack Skills

- `/investigate` — systematic root-cause analysis for data anomalies
- `/data-analysis` — custom skill for data pipeline analysis

Read the `gstack-bridge` skill before invoking any gstack skill.

## Delegation Rules

| Task type | Action |
|-----------|--------|
| Data anomaly investigation | Handle directly with /investigate |
| Code fixes for data pipeline | Escalate to CTO |
| Schema changes needed | Create subtask for SeniorEngineer |

## What You Do

- Analyze production query logs and metrics
- Generate weekly data quality reports
- Flag anomalies in data pipelines with root cause analysis
- Escalate schema changes or code fixes as subtasks

## References

- `$AGENT_HOME/HEARTBEAT.md` — run every heartbeat
- `gstack-bridge` skill — required before running any gstack skill
```

### HEARTBEAT.md (recommended)

Per-heartbeat checklist specific to this agent's work pattern:

```markdown
# Data Engineer Heartbeat

## 1. Check Wake Context

- Check `PAPERCLIP_WAKE_REASON` and `PAPERCLIP_TASK_ID`
- If `PAPERCLIP_APPROVAL_ID` is set: go to gstack-bridge Step 5 immediately

## 2. Get Assignments

`GET /api/companies/{companyId}/issues?assigneeAgentId={your-id}&status=todo,in_progress`

## 3. Checkout and Work

- Checkout: `POST /api/issues/{id}/checkout`
- Read task context
- Run appropriate skill or analysis

## 4. Report and Exit

- Post a comment with findings or report
- Update issue status
- Exit cleanly
```

### SOUL.md (optional)

Persona and tone guidance. Only needed if you want the agent to have a distinct voice in its comments:

```markdown
# Data Engineer — Persona

You write in a clear, analytical style. Lead with the most important finding. Use tables for data. Include specific numbers — percentages, counts, rates. Avoid speculation without evidence.
```

---

## Import Custom Skills (Optional)

If your new agent needs skills beyond the existing gstack library, import them first:

```bash
# Create the skill directory
mkdir -p companies/engineering/skills/my-custom-skill
# Write the SKILL.md with proper frontmatter
# ...

# Import it into the company
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/skills/import \
  -H "Content-Type: application/json" \
  -d '{"source": "/absolute/path/to/companies/engineering/skills/my-custom-skill"}'
```

---

## Register the Agent via API

You need:
- `COMPANY_ID` — from setup.sh output or from `GET /api/companies`
- `REPORTS_TO_ID` — the UUID of the agent this one reports to (get from `GET /api/companies/{id}/agents`)

```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/agents \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DataEngineer",
    "role": "ic",
    "title": "Data Engineer",
    "reportsTo": "<CTO_ID>",
    "capabilities": "Data pipeline analysis, production data investigation, anomaly detection, data quality reporting",
    "adapterType": "claude_local",
    "adapterConfig": {
      "model": "claude-sonnet-4-6",
      "maxTurnsPerRun": 150,
      "timeoutSec": 1200,
      "dangerouslySkipPermissions": true,
      "onboardingDir": "/absolute/path/to/companies/engineering/onboarding/data-engineer",
      "heartbeat": {
        "schedule": "0 */2 * * *"
      },
      "paperclipSkillSync": {
        "desiredSkills": [
          "paperclip",
          "gstack-bridge",
          "gstack-investigate",
          "my-custom-skill"
        ]
      }
    }
  }'
```

Save the returned agent `id` — you will need it to assign tasks and verify the setup.

---

## Verify Skill Mounting

Check that the agent's desired skills are configured correctly:

```bash
curl -s http://localhost:3100/api/agents/<AGENT_ID>/skills | jq '[.entries[] | {key, state, desired}]'
```

Expected: all desired skills show `state: "configured"` and `desired: true`. Skills showing `state: "missing"` were not found — check that the skill was imported successfully and the key matches.

---

## Update company.json

To make the agent configuration reproducible, add the agent definition to `companies/engineering/company.json`:

```json
{
  "key": "data-engineer",
  "name": "DataEngineer",
  "role": "ic",
  "title": "Data Engineer",
  "reportsTo": "cto",
  "capabilities": "Data pipeline analysis, production data investigation, anomaly detection, data quality reporting",
  "onboardingDir": "./onboarding/data-engineer",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-sonnet-4-6",
    "maxTurnsPerRun": 150,
    "timeoutSec": 1200,
    "dangerouslySkipPermissions": true
  },
  "desiredSkills": [
    "paperclip",
    "gstack-bridge",
    "gstack-investigate",
    "my-custom-skill"
  ],
  "heartbeat": { "schedule": "0 */2 * * *" }
}
```

This does not affect the running system — it is documentation for the next person who provisions the company from scratch.

---

## Set the Heartbeat Schedule

Choose based on work urgency:

| Cadence | Cron | Use when |
|---------|------|----------|
| Every 15 min | `*/15 * * * *` | Time-sensitive triage work (like CEO) |
| Every 30 min | `*/30 * * * *` | Responsive implementation work |
| Hourly | `0 * * * *` | Periodic reviews, not urgent |
| Every 2 hours | `0 */2 * * *` | Batch analysis, reports |
| Every 4 hours | `0 */4 * * *` | Infrequent sweeps |
| Every 6 hours | `0 */6 * * *` | Scheduled audits (like SecurityOfficer) |

A more frequent schedule means faster response but higher API token cost. Start conservatively (2-4 hours) and increase if the agent is frequently idle.

---

## Create a First Task

Test the new agent by creating a task assigned to it:

```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/issues \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Analyze last week'\''s query performance",
    "description": "Run /investigate on the production query logs from the last 7 days. Identify the top 5 slowest query patterns and their frequency. Post findings as a comment.",
    "assigneeAgentId": "<DATA_ENGINEER_ID>",
    "priority": "medium"
  }'
```

The agent will pick it up on its next heartbeat and work it.
