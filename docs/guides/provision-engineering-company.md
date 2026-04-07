# Provision the Engineering Company

How to run `setup.sh`, what it does, how to verify it worked, and how to troubleshoot the most common failures.

---

## Prerequisites

Before running setup:

- Paperclip server running on `http://localhost:3100` (or your configured URL)
- `jq` installed and in your PATH
- You are in the `companies/engineering/` directory, or the repo root

Verify:
```bash
curl -s http://localhost:3100/api/health | jq .status
# Expected: "ok"

jq --version
# Expected: jq-1.6 or higher
```

---

## Run the Setup Script

```bash
cd companies/engineering
./setup.sh
```

If your Paperclip server runs on a different port:
```bash
PAPERCLIP_URL=http://localhost:4040 ./setup.sh
```

The script runs in 4 steps and takes about 30-60 seconds.

---

## What setup.sh Does

### Step 1: Create the Company

```bash
POST /api/companies
{ "name": "Engineering Co", "issuePrefix": "ENG" }
```

Creates the company record in Paperclip. Saves the returned company UUID for use in subsequent steps.

### Step 2: Import gstack Skills

For each of the 26 gstack skills (autoplan, plan-ceo-review, office-hours, ...), the script calls:

```bash
POST /api/companies/{COMPANY_ID}/skills/import
{ "source": "/absolute/path/to/gstack/<skill-name>" }
```

The import stores the absolute path to each skill directory so Paperclip can create symlinks at runtime. The gstack skills are sourced from `../../gstack/` relative to `companies/engineering/`.

The script also imports the built-in `paperclip` skill from `paperclip/skills/paperclip/` if that directory exists.

### Step 3: Import the Bridge Skill

```bash
POST /api/companies/{COMPANY_ID}/skills/import
{ "source": "/absolute/path/to/companies/engineering/skills/gstack-bridge" }
```

The bridge skill (`gstack-bridge`) is sourced from `companies/engineering/skills/gstack-bridge/` — the custom integration skill that lives in this repo, not in gstack.

### Step 4: Create Agents

The script creates all 9 agents in dependency order (parents before children). For each agent, it calls:

```bash
POST /api/companies/{COMPANY_ID}/agents
{
  "name": "CEO",
  "role": "ceo",
  "title": "Chief Executive Officer",
  "reportsTo": null,
  "capabilities": "...",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-haiku-4-5-20251001",
    "maxTurnsPerRun": 80,
    "timeoutSec": 900,
    "dangerouslySkipPermissions": true,
    "onboardingDir": "/absolute/path/to/onboarding/ceo",
    "heartbeat": { "schedule": "*/15 * * * *" },
    "paperclipSkillSync": {
      "desiredSkills": ["paperclip", "gstack-bridge", "autoplan", ...]
    }
  }
}
```

The `onboardingDir` is the absolute path to the agent's onboarding directory (e.g., `onboarding/ceo/`). Paperclip reads the Markdown files from this directory and includes them in the agent's system prompt.

The `desiredSkills` list is the set of skill keys (matching the imported skill keys) that Paperclip should mount for this agent on each run.

---

## Verify the Setup

### Check the Company Exists

```bash
curl -s http://localhost:3100/api/companies | jq '.[].name'
# Expected: "Engineering Co"
```

### List Agents

```bash
curl -s "http://localhost:3100/api/companies/<COMPANY_ID>/agents" | jq '[.[] | {name: .name, role: .role}]'
```

Expected output:
```json
[
  { "name": "CEO", "role": "ceo" },
  { "name": "CTO", "role": "cto" },
  { "name": "SeniorEngineer", "role": "engineer" },
  { "name": "ReleaseEngineer", "role": "devops" },
  { "name": "DevExEngineer", "role": "engineer" },
  { "name": "QALead", "role": "qa" },
  { "name": "QAEngineer", "role": "qa" },
  { "name": "SecurityOfficer", "role": "general" },
  { "name": "DesignLead", "role": "designer" }
]
```

### Check Skills Were Imported

```bash
curl -s "http://localhost:3100/api/companies/<COMPANY_ID>/skills" | jq '[.[] | .key]'
```

Expected: a JSON array containing `autoplan`, `review`, `gstack-bridge`, `qa`, and 25+ other skill keys.

> **Note on skill key naming:** gstack skills are imported with their bare slug (e.g., `autoplan`, `review`, `qa`). Only `gstack-bridge` retains the `gstack-` prefix because it is sourced from `companies/engineering/skills/` rather than the `gstack/` directory. Use the bare slug when referencing gstack skills in `desiredSkills`.

### Open the Web UI

Navigate to [http://localhost:3100](http://localhost:3100). You should see:
- "Engineering Co" in the companies list
- All 9 agents in the Agents panel
- An empty Issues board

---

## Re-running setup.sh

The setup script is not currently idempotent — running it twice will create a second company named "Engineering Co" with a new set of agents. To re-run cleanly:

1. Delete the company created in the first run (via the Paperclip UI: Settings → Company → Delete, or via the API)
2. Run `./setup.sh` again

Alternatively, if you want to add agents or skills to an existing company without recreating it, use the API directly (see [Add a New Agent](add-a-new-agent.md) and [Add a Custom Skill](add-a-custom-skill.md)).

---

## Troubleshooting

### Failure: `curl: (7) Failed to connect`

The Paperclip server is not running. Start it:
```bash
cd paperclip
pnpm dev:server
```

Wait for `Server listening on http://localhost:3100` before re-running setup.

> **Windows note:** Use `pnpm dev:server` instead of `pnpm dev`. On Windows, `pnpm dev` hangs after running database migrations because the watch process does not exit cleanly. `pnpm dev:server` starts only the server process and works correctly.

### Failure: `jq: command not found`

Install jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows
winget install jqlang.jq
```

### Failure: `WARNING: gstack skill not found: /path/to/gstack/<skill>`

The gstack skills directory is not at the expected relative path (`../../gstack/` from `companies/engineering/`). Verify the repository structure:

```bash
ls ../../gstack/
# Should list: autoplan, plan-ceo-review, review, ship, qa, etc.
```

If gstack is not present, the repo was not cloned correctly. Ensure you cloned the full `gstack_paperclip` repository, not just the `paperclip/` or `companies/` subdirectories.

### Failure: Script exits with no output on a skill import

The Paperclip API returned an error for a specific skill import. Enable verbose output:
```bash
set -x  # uncomment at top of setup.sh temporarily
./setup.sh 2>&1 | head -50
```

Common causes:
- The skill directory does not contain a valid `SKILL.md` with frontmatter
- The API server is running but the skills endpoint returned a 4xx error (check for validation issues)
- The `source` path contains spaces that break the JSON — verify your absolute paths
- **Windows:** The `source` path uses backslashes (`C:\Users\...`) instead of forward slashes (`C:/Users/...`). The Paperclip skill import API requires forward-slash paths on Windows. The `setup.sh` script uses `cygpath -m` to convert paths — verify it is producing `C:/` style paths and not `C:\` style paths.

### Agents created but skills show as "missing" in the UI

This means the `desiredSkills` list references skill keys that were not imported successfully. Check the imported skills list against the desired skills list for each agent. Skills that failed to import (due to the path error above) will appear as `state: "missing"` in the agent's skill panel.

Fix by importing the missing skills individually:
```bash
curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/skills/import \
  -H "Content-Type: application/json" \
  -d '{"source": "/absolute/path/to/gstack/<skill-name>"}'
```
