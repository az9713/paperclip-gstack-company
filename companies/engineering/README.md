# gstack Engineering Company

A Paperclip company template that models a full autonomous engineering team. Each agent is provisioned with role-specific [gstack](../../gstack) skills — Paperclip provides the org structure and orchestration, gstack provides the engineering expertise.

**One sentence:** Paperclip gives agents their jobs. gstack gives agents their skills.

---

## The Team

```
Human (Board Operator)
└── CEO
    ├── CTO
    │   ├── SeniorEngineer
    │   ├── ReleaseEngineer
    │   └── DevExEngineer
    ├── QALead
    │   └── QAEngineer
    ├── SecurityOfficer
    └── DesignLead
```

| Agent | gstack Skills | Heartbeat |
|-------|--------------|-----------|
| CEO | `/autoplan`, `/plan-ceo-review`, `/office-hours` | every 15 min |
| CTO | `/plan-eng-review`, `/review`, `/ship` | every 20 min |
| SeniorEngineer | `/investigate`, `/codex` | every 30 min |
| ReleaseEngineer | `/land-and-deploy`, `/canary`, `/document-release`, `/setup-deploy` | every 30 min |
| DevExEngineer | `/devex-review`, `/plan-devex-review`, `/retro`, `/benchmark` | hourly |
| QALead | `/qa-only` | every 4 hours |
| QAEngineer | `/qa` | every 30 min |
| SecurityOfficer | `/cso`, `/careful`, `/guard` | every 6 hours |
| DesignLead | `/design-review`, `/design-html`, `/design-consultation`, `/design-shotgun`, `/plan-design-review` | every 30 min |

---

## Quick Start

### Prerequisites

- Paperclip server running (`cd paperclip && npm run dev`)
- `jq` installed
- gstack skills directory present at `../../gstack/`

### Provision

```bash
cd companies/engineering
./setup.sh
```

This will:
1. Create the Engineering Co company in Paperclip
2. Import all gstack skills as company skills
3. Import the `gstack-bridge` skill
4. Create all 9 agents with correct org chart, skills, and heartbeat schedules

Set a custom Paperclip URL if needed:
```bash
PAPERCLIP_URL=http://localhost:4040 ./setup.sh
```

### Start a task

After setup, create an issue assigned to the CEO:

```bash
curl -X POST http://localhost:4040/api/companies/{COMPANY_ID}/issues \
  -H "Content-Type: application/json" \
  -d '{"title": "Build user authentication with OAuth2", "assigneeAgentId": "{CEO_ID}"}'
```

The CEO will triage and delegate to the right agents automatically.

---

## How It Works

### Paperclip + gstack Integration

gstack skills are interactive — they use `AskUserQuestion` to pause and ask the human for decisions. Paperclip runs agents headlessly (`--print -`), so `AskUserQuestion` would fail.

The `gstack-bridge` skill solves this by teaching agents:

1. **Mechanical decisions** (version bump level, stash dirty tree, write CHANGELOG) → auto-decide using defaults
2. **Judgment decisions** (ASK review items, pre-merge readiness gate, production health) → create a Paperclip approval, set issue to `blocked`, exit. Human approves in the dashboard. Agent resumes via `--resume`.
3. **Cross-role phases** (e.g., `/autoplan`'s design review phase) → create a subtask assigned to the appropriate specialist agent

### Approval Flow

When an agent hits a judgment checkpoint (e.g., CTO running `/review` finds ASK items):

1. Agent creates an approval via `POST /api/companies/{id}/approvals` with type `gstack_checkpoint`
2. Agent posts the checkpoint question and options as an issue comment
3. Agent sets issue to `blocked` and exits
4. Human sees the pending approval in the Paperclip dashboard
5. Human approves with their choice
6. Paperclip wakes the agent with `--resume` + `PAPERCLIP_APPROVAL_ID`
7. Agent reads the decision and continues the gstack skill

### Delegation Flow

When a gstack skill would cross a role boundary:

- `/ship` needs a review → CTO creates subtask for itself or SeniorEngineer
- `/autoplan` hits design phase → CEO creates subtask for DesignLead
- `/autoplan` hits eng phase → CEO creates subtask for CTO
- QALead finds bugs via `/qa-only` → creates fix subtasks for QAEngineer

---

## File Structure

```
companies/engineering/
├── README.md                    # this file
├── company.json                 # agent definitions (reference — setup.sh creates from this)
├── setup.sh                     # provisioning script
│
├── skills/
│   └── gstack-bridge/
│       ├── SKILL.md             # bridge skill: headless gstack operation
│       └── references/
│           └── checkpoint-map.md # per-skill checkpoint inventory + defaults
│
├── onboarding/                  # per-agent instruction bundles
│   ├── ceo/
│   │   ├── AGENTS.md            # CEO role, delegation rules, gstack skills
│   │   ├── HEARTBEAT.md         # CEO heartbeat checklist
│   │   └── SOUL.md              # CEO persona
│   ├── cto/
│   │   ├── AGENTS.md
│   │   └── HEARTBEAT.md
│   ├── senior-engineer/AGENTS.md
│   ├── release-engineer/AGENTS.md
│   ├── devex-engineer/AGENTS.md
│   ├── qa-lead/AGENTS.md
│   ├── qa-engineer/AGENTS.md
│   ├── security-officer/AGENTS.md
│   └── design-lead/AGENTS.md
│
└── gstack-deps/                 # gstack reference files
    ├── ETHOS.md -> ../../../gstack/ETHOS.md
    ├── checklist.md -> ../../../gstack/review/checklist.md
    └── TODOS-format.md -> ../../../gstack/review/TODOS-format.md
```

---

## Checkpoints Reference

See `skills/gstack-bridge/references/checkpoint-map.md` for the full per-skill checkpoint inventory — which decisions are auto-decided vs. which create Paperclip approvals.

Key rules:
- AUTO-FIX review findings → always applied
- Version bump → MICRO (4th digit) by default
- Pre-merge readiness gate → **always** creates approval
- WTF-likelihood > 20% in `/qa` → creates approval
- `/autoplan` premise gate and final approval → always creates approval

---

## Modifying the Team

To add an agent or change skill assignments, edit `company.json` for reference, then:

```bash
# Add a new agent manually
curl -X POST http://localhost:4040/api/companies/{COMPANY_ID}/agents \
  -H "Content-Type: application/json" \
  -d '{
    "name": "NewAgent",
    "role": "ic",
    "title": "...",
    "reportsTo": "{PARENT_AGENT_ID}",
    "adapterType": "claude_local",
    "adapterConfig": { ... },
    "desiredSkills": ["paperclip", "gstack-bridge", "gstack-<skill>"]
  }'
```

To add a new gstack skill to the company library:
```bash
curl -X POST http://localhost:4040/api/companies/{COMPANY_ID}/skills/import \
  -H "Content-Type: application/json" \
  -d '{"source": "/absolute/path/to/gstack/<skill>"}'
```
