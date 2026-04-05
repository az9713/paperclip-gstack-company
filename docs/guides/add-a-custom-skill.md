# Add a Custom Skill

How to create a custom SKILL.md, import it into the Engineering Company, assign it to agents, and test that it works.

---

## The SKILL.md Format

A skill is a directory containing a `SKILL.md` file. The file has two sections: YAML frontmatter and the skill body.

### Minimal SKILL.md

```markdown
---
name: my-skill
description: |
  One-paragraph description of what this skill does and when to use it.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# My Skill

Brief intro paragraph.

## Step 1: Do the first thing

Instructions for step 1. Be specific — the agent follows these literally.

```bash
# Example command the agent should run
ls -la
```

## Step 2: Do the second thing

More instructions.

## Step 3: Report results

Post a comment summarizing what was done:

```
POST /api/issues/{PAPERCLIP_TASK_ID}/comments
{ "body": "## My Skill Results\n\n{summary}" }
```
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier. Must match the directory name. Used as the slash command (e.g., `name: my-skill` → `/my-skill`). |
| `description` | Yes | One-paragraph description. Shown in skill help. Used by the gstack-bridge skill to route tasks to this skill. |
| `allowed-tools` | Yes | List of Claude Code tools this skill uses. Common values: `Bash`, `Read`, `Write`, `Edit`. Add `AskUserQuestion` only if you handle it with the bridge skill approval protocol. |
| `version` | No | Semantic version for upgrade tracking. |
| `preamble-tier` | No | Controls ETHOS preamble injection. Omit for custom skills unless you want the gstack builder philosophy injected. |

### Writing Effective Skill Instructions

**Be explicit about every step.** The agent follows the skill instructions literally. If a step is ambiguous, the agent will infer — and may infer incorrectly.

**State decisions explicitly.** Instead of "check if tests pass", write "Run the test suite. If all tests pass, continue to Step 3. If any tests fail, stop here and post a comment listing the failing tests."

**Include API call examples.** If the skill interacts with Paperclip APIs, include the exact endpoint, method, headers, and body format. Agents follow examples more reliably than descriptions.

**Handle the checkpoint decision.** For each decision point in your skill, decide: is this mechanical (auto-decide with a sensible default) or judgment (needs human input)? Document this explicitly:

```markdown
## Checkpoint: Should we proceed?

In Paperclip mode (PAPERCLIP_AGENT_ID is set): 
- If the analysis shows < 3 issues: proceed automatically
- If the analysis shows >= 3 issues: create a gstack_checkpoint approval asking the human whether to fix or defer
```

---

## Example: A Data Pipeline Check Skill

Here is a complete example of a custom skill for a Data Engineer agent:

```markdown
---
name: data-pipeline-check
description: |
  Analyzes production data pipeline health. Checks for stuck jobs, schema drift,
  data freshness issues, and anomalous row counts. Produces a structured health report.
  Run when assigned a data pipeline monitoring task.
allowed-tools:
  - Bash
  - Read
---

# Data Pipeline Health Check

Run this skill when you receive a task to check data pipeline health.

## Step 1: Identify the Pipeline

Read the task description to understand which pipeline to check.
If no specific pipeline is mentioned, check all pipelines in `src/pipelines/`.

```bash
ls src/pipelines/
```

## Step 2: Check for Stuck Jobs

```bash
# Check for jobs that have not completed in the last 2 hours
cat logs/pipeline-status.log | grep -E "started|completed" | tail -100
```

If any job started more than 2 hours ago without completing, record it as a **stuck job**.

## Step 3: Check Data Freshness

```bash
# Check timestamp of latest records in key tables
cat config/pipeline-tables.json
```

For each table in the config, note whether it was updated within its expected refresh window.

## Step 4: Generate Report

Post a comment on the current issue:

```
POST /api/issues/{PAPERCLIP_TASK_ID}/comments
Headers: X-Paperclip-Run-Id: {PAPERCLIP_RUN_ID}
{
  "body": "## Data Pipeline Health Report\n\n**Checked at:** {timestamp}\n\n### Stuck Jobs\n{list or 'None'}\n\n### Data Freshness\n{table-by-table summary}\n\n### Recommendation\n{next action}"
}
```

## Step 5: Escalate if Needed

In Paperclip mode: if any stuck jobs were found, create a gstack_checkpoint approval:

```
type: gstack_checkpoint
payload:
  skill: data-pipeline-check
  step: stuck jobs found
  question: Found {N} stuck jobs. Should we alert the on-call engineer?
  options:
    A: Create an alert task and assign to SeniorEngineer
    B: Log and continue — not urgent enough for escalation
  recommendation: A (if N > 2), B (if N == 1)
```
```

---

## Create the Skill Directory

```bash
mkdir -p companies/engineering/skills/data-pipeline-check
```

Write your `SKILL.md`:

```bash
# Create the file at:
# companies/engineering/skills/data-pipeline-check/SKILL.md
```

---

## Import the Skill into the Company

```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/skills/import \
  -H "Content-Type: application/json" \
  -d '{"source": "/absolute/path/to/companies/engineering/skills/data-pipeline-check"}'
```

Response:
```json
{
  "imported": [
    { "slug": "data-pipeline-check", "name": "data-pipeline-check" }
  ]
}
```

The `slug` is the key used in `desiredSkills` configuration.

---

## Assign the Skill to an Agent

Update the agent's desired skills via PATCH:

```bash
curl -X PATCH http://localhost:3100/api/agents/<AGENT_ID> \
  -H "Content-Type: application/json" \
  -d '{
    "adapterConfig": {
      "paperclipSkillSync": {
        "desiredSkills": [
          "paperclip",
          "gstack-bridge",
          "gstack-investigate",
          "data-pipeline-check"
        ]
      }
    }
  }'
```

> **Note:** The full `desiredSkills` array replaces the existing one. Include all skills you want the agent to have, not just the new one.

---

## Verify the Skill Is Configured

```bash
curl -s http://localhost:3100/api/agents/<AGENT_ID>/skills | \
  jq '.entries[] | select(.key == "data-pipeline-check")'
```

Expected:
```json
{
  "key": "data-pipeline-check",
  "desired": true,
  "state": "configured",
  "detail": "Will be mounted into the ephemeral Claude skill directory on the next run."
}
```

If `state` is `"missing"`, the import failed or the key does not match. Re-run the import and check the returned `slug` matches what you put in `desiredSkills`.

---

## Test the Skill

Create a task that explicitly invokes your skill:

```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/issues \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Check data pipeline health",
    "description": "Run /data-pipeline-check on all pipelines in src/pipelines/. Report findings.",
    "assigneeAgentId": "<AGENT_ID>",
    "priority": "medium"
  }'
```

On the next heartbeat, the agent should:
1. Read the task
2. Identify `/data-pipeline-check` as the target skill (from the explicit command in the description)
3. Read the bridge skill
4. Read your `data-pipeline-check/SKILL.md`
5. Follow the steps and post a report

Check the task's comments to see the agent's output.

---

## Update company.json

Add the new skill to the `skills` array in `company.json` so it will be imported on future provisioning runs:

```json
{ "key": "data-pipeline-check", "sourcePath": "./skills/data-pipeline-check" }
```
