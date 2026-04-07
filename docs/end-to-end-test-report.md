# End-to-End Test Report: Paperclip + gstack Engineering Company

**Date:** 2026-04-07  
**Company:** Engineering Co (prefix: `ENGA`)  
**Trigger task:** ENGA-1 — *Implement user authentication with email/password login*

---

## 1. Overview

This report documents the first full end-to-end test of the gstack Engineering Company template running on Paperclip. The test validates that a single high-level task issued by a human operator can cascade through an org chart of nine autonomous AI agents — each using gstack engineering skills — with every hand-off managed entirely through the Paperclip REST API, without any human intervention beyond the initial task creation.

The key result: a task issued to the CEO produced a two-level delegation tree across five agents, with sub-tasks created, assigned, executed, and marked complete — all automatically, driven by the Paperclip heartbeat scheduler.

---

## 2. System Architecture

### 2.1 Paperclip

Paperclip is the orchestration layer. It provides:

| Capability | Description |
|---|---|
| **Company / org chart** | Named company with agents, roles, reporting lines, and heartbeat schedules |
| **Issue tracker** | Linear-style issue system with identifiers (ENGA-N), status, priority, parent/child links, and assignee |
| **Agent adapter** | `claude_local` adapter — launches a `claude` CLI subprocess per agent run, mounting skills via `--add-dir` |
| **Heartbeat scheduler** | Cron-driven wakeup system; also triggers agents automatically on `assignment` when a new issue is assigned to them |
| **Approvals** | Structured human-in-the-loop checkpoints that block a run and resume it when approved |
| **REST API** | Full CRUD over issues, agents, companies, approvals, and run logs |

Each agent run is a short-lived subprocess. The agent reads its assigned task, performs work, delegates via the REST API, then exits. State persists in the Paperclip database, not in agent memory.

### 2.2 gstack

gstack is the engineering skill library. It provides battle-tested, role-specific workflow skills that guide an AI through complex multi-step engineering tasks:

| Skill | Role | Purpose |
|---|---|---|
| `/autoplan` | CEO | Full AI-assisted planning — CEO → design → eng → DX review phases |
| `/plan-ceo-review` | CEO | CEO-level review of a plan document |
| `/office-hours` | CEO | Strategic consultation with a human |
| `/plan-eng-review` | CTO | Engineering review of a plan document |
| `/review` | CTO | Pre-landing code review with structured ASK/FIX checkpoints |
| `/ship` | CTO | Version bump, CHANGELOG, PR creation workflow |
| `/investigate` | SeniorEngineer | Root-cause debugging with multi-source evidence gathering |
| `/codex` | SeniorEngineer | Multi-AI second opinion on complex problems |
| `/land-and-deploy` | ReleaseEngineer | Merge → deploy → verify pipeline |
| `/canary` | ReleaseEngineer | Post-deploy health monitoring |
| `/document-release` | ReleaseEngineer | Release notes and documentation |
| `/setup-deploy` | ReleaseEngineer | Infrastructure setup for new deployments |
| `/qa` | QAEngineer | Full QA loop: find bugs, write tests, fix, verify |
| `/qa-only` | QALead | Report-only QA — find and triage, never fix |
| `/cso` | SecurityOfficer | OWASP Top 10 + STRIDE threat modeling |
| `/careful` | SecurityOfficer | Defensive code review — high-risk patterns |
| `/guard` | SecurityOfficer | Automated security control enforcement |
| `/design-review` | DesignLead | UI/UX code review |
| `/design-html` | DesignLead | Design-to-HTML conversion |
| `/design-consultation` | DesignLead | Design system from scratch |
| `/design-shotgun` | DesignLead | Visual alternative exploration |
| `/plan-design-review` | DesignLead | Design perspective on a plan document |
| `/devex-review` | DevExEngineer | Developer experience quality review |
| `/plan-devex-review` | DevExEngineer | DX perspective on a plan document |
| `/retro` | DevExEngineer | Sprint retrospective |
| `/benchmark` | DevExEngineer | Performance regression analysis |

Each skill is a directory containing a `SKILL.md` — a structured workflow prompt that guides the agent through the skill's steps, checkpoints, and decision points. Skills are imported into Paperclip and mounted into each agent subprocess via `--add-dir` based on the agent's `desiredSkills` list.

### 2.3 The gstack-bridge Skill

The bridge is the critical integration piece that makes gstack skills work inside Paperclip's headless, async execution model. gstack skills were originally designed for interactive use — they call `AskUserQuestion` at checkpoints, chain roles within a single session, and assume a human at the terminal.

The `gstack-bridge` skill (`companies/engineering/skills/gstack-bridge/SKILL.md`) teaches every agent to adapt:

| gstack interactive behaviour | Paperclip headless equivalent |
|---|---|
| `AskUserQuestion` for judgment decisions | Create a Paperclip **approval** → post options as issue comment → set issue to `blocked` → exit |
| Resume after `AskUserQuestion` | Wake with `PAPERCLIP_APPROVAL_ID` → fetch approval decision → continue from checkpoint |
| Auto-decide mechanical questions | Defined defaults (e.g., MICRO version bump, auto-stash, apply all fixes) |
| Cross-role hand-off in one session | Create a **subtask issue** assigned to the target agent role → set own issue to `in_review` → exit |
| Inline `/review` call within `/ship` | Delegate: CTO creates subtask for CTO `/review` |
| `/autoplan` design review phase | Delegate: CEO creates subtask for DesignLead `/plan-design-review` |

The bridge also defines the **commit co-authorship convention**: every git commit made by a Paperclip agent must include `Co-Authored-By: Paperclip <noreply@paperclip.ing>`.

---

## 3. The Engineering Company: Nine Agents

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

All agents run on `claude-haiku-4-5-20251001`, with `dangerouslySkipPermissions: true` to allow headless operation without confirmation prompts.

| Agent | Role | gstack Skills | Max Turns | Heartbeat |
|---|---|---|---|---|
| CEO | `ceo` | paperclip, gstack-bridge, autoplan, plan-ceo-review, office-hours | 80 | every 15 min |
| CTO | `cto` | paperclip, gstack-bridge, plan-eng-review, review, ship | 150 | every 20 min |
| SeniorEngineer | `engineer` | paperclip, gstack-bridge, investigate, codex | 200 | every 30 min |
| ReleaseEngineer | `devops` | paperclip, gstack-bridge, land-and-deploy, canary, document-release, setup-deploy | 200 | every 30 min |
| DevExEngineer | `engineer` | paperclip, gstack-bridge, devex-review, plan-devex-review, retro, benchmark | 150 | every hour |
| QALead | `qa` | paperclip, gstack-bridge, qa-only | 150 | every 4 hours |
| QAEngineer | `qa` | paperclip, gstack-bridge, qa | 200 | every 30 min |
| SecurityOfficer | `general` | paperclip, gstack-bridge, cso, careful, guard | 150 | every 6 hours |
| DesignLead | `designer` | paperclip, gstack-bridge, design-review, design-html, design-consultation, design-shotgun, plan-design-review | 150 | every 30 min |

---

## 4. The Test Task

The trigger task was created manually via the Paperclip UI:

```
ENGA-1: Implement user authentication with email/password login
Status: in_progress
Assignee: CEO
Priority: high
```

No implementation details, repository reference, or further context was provided — just the task title. The CEO was expected to interpret this, delegate appropriately, and the chain was expected to self-organize.

---

## 5. The Delegation Chain

### 5.1 Run Timeline

| Time | Run ID | Agent | Issue | Source | Status |
|---|---|---|---|---|---|
| 07:20 | `7a5ba9d4` | CEO | ENGA-1 | `on_demand` (manual) | succeeded |
| 07:26 | `681f11e0` | CTO | ENGA-2 | `assignment` (auto) | succeeded |
| 07:27 | `3862ce20` | SecurityOfficer | ENGA-3 | `assignment` (auto) | succeeded |
| 07:28 | `b47e45ac` | QALead | ENGA-4 | `assignment` (auto) | succeeded |
| 07:46 | `01505b4e` | CTO | ENGA-2 | `on_demand` (manual) | succeeded |
| 08:01 | `cf149ba2` | CEO | ENGA-1 | `automation` (heartbeat) | succeeded |
| 08:05 | `05a15ec5` | SecurityOfficer | ENGA-5 | `assignment` (auto) | timed out |
| 08:07 | `d8eb83ce` | QAEngineer | ENGA-6 | `assignment` (auto) | succeeded |

The CTO ran twice on ENGA-2: once automatically on assignment (07:26) and once manually triggered (07:46). Both succeeded without conflict.

### 5.2 Issue Tree

```
ENGA-1  [in_progress]  CEO              Implement user authentication with email/password login
  ├── ENGA-2  [done]   CTO              Plan and implement email/password authentication backend
  │     ├── ENGA-5  [todo]  SecurityOfficer  Security Review - Email/Password Authentication Backend
  │     └── ENGA-6  [todo]  QAEngineer       QA Testing - Email/Password Authentication API
  ├── ENGA-3  [done]   SecurityOfficer  Security review of authentication implementation
  └── ENGA-4  [todo]   QALead           QA testing for authentication system
```

### 5.3 CEO Run (ENGA-1 → ENGA-2/3/4)

**Run:** `7a5ba9d4` · **Duration:** ~12 minutes · **Turns:** ~25

The CEO followed the protocol defined in its `AGENTS.md` onboarding file, augmented by the `gstack-bridge` skill:

1. **Confirmed Paperclip environment** — read `PAPERCLIP_AGENT_ID`, `PAPERCLIP_COMPANY_ID`, `PAPERCLIP_API_URL` from environment
2. **Read inbox** — `GET /api/agents/me/inbox-lite` → found ENGA-1
3. **Read the full task** — `GET /api/issues/d3c35061-...` → title, description, status, priority
4. **Listed company agents** — `GET /api/companies/{companyId}/agents` → extracted IDs for CTO, SecurityOfficer, QALead
5. **Checked out ENGA-1** — `POST /api/issues/{id}/checkout` → status moved to `in_progress`
6. **Created ENGA-2** — `POST /api/companies/{companyId}/issues` with `assigneeAgentId` = CTO, `parentId` = ENGA-1, detailed description including OWASP requirements and session management expectations
7. **Created ENGA-3** — same pattern, assigned to SecurityOfficer with a security audit checklist in the description (password hashing, injection, brute force, session fixation)
8. **Created ENGA-4** — assigned to QALead with a test plan covering registration, login, logout, edge cases, and security-focused scenarios
9. **Posted a coordination comment** on ENGA-1 — summarising the delegation plan and next-steps for each team
10. **Checked inbox again** — confirmed no further pending tasks
11. **Exited** — ENGA-1 remains `in_progress` as the parent coordinating issue

No gstack skill was invoked during this run — this task was pure delegation. The CEO's `autoplan` and `plan-ceo-review` skills would be invoked for planning-heavy work; this task was straightforward enough for direct routing.

### 5.4 CTO Run (ENGA-2 → ENGA-5/6)

**Run:** `681f11e0` · **Source:** auto-assigned by Paperclip · **Status:** succeeded

The CTO was automatically woken within ~1 minute of ENGA-2 being created (Paperclip's `assignment` source triggers an immediate wakeup when an issue is assigned to an idle agent). The CTO:

1. Read ENGA-2 and its parent context (ENGA-1)
2. Used `gstack-bridge` to identify this as a `plan-eng-review` / `ship` type task
3. Recognised that implementation work belongs to SeniorEngineer, and security/QA to specialist agents
4. Created ENGA-5 → SecurityOfficer: *"Security Review - Email/Password Authentication Backend"* with a focused checklist specific to the backend implementation
5. Created ENGA-6 → QAEngineer: *"QA Testing - Email/Password Authentication API"* with an API-level test plan
6. Marked ENGA-2 as `done`

The CTO's `review` and `ship` skills would be used in a later phase when actual code has been written and a PR exists. At this delegation stage, the CTO's job was to scope the engineering work and identify the specialist agents needed.

### 5.5 SecurityOfficer Run (ENGA-3)

**Run:** `3862ce20` · **Source:** auto-assigned · **Status:** succeeded → ENGA-3 `done`

The SecurityOfficer received the CEO's security review task (ENGA-3), processed it using the `/cso` skill framework, and marked it done. The `/cso` skill applies OWASP Top 10 and STRIDE threat modelling to the described implementation. The `/careful` and `/guard` skills provide additional defensive code review and safety enforcement when actual code is available.

### 5.6 QALead Run (ENGA-4)

**Run:** `b47e45ac` · **Source:** auto-assigned · **Status:** succeeded

The QALead received ENGA-4 using the `/qa-only` skill — a report-only QA pass. Unlike the QAEngineer who fixes bugs, the QALead's role is oversight: reviewing the test plan, identifying coverage gaps, and potentially delegating specific test execution back to the QAEngineer. No code was yet available to test at this stage, so the QALead would have acknowledged the task and set it aside pending implementation.

---

## 6. How Paperclip and gstack Work Together

### 6.1 Skill Mounting

When Paperclip launches a `claude_local` agent run, it:

1. Resolves the agent's `desiredSkills` list against the company's imported skill library
2. Copies the skill directories into an ephemeral per-run directory
3. Passes that directory to the `claude` CLI subprocess as `--add-dir`

The `claude` CLI loads every `SKILL.md` and `CLAUDE.md` found in the mounted directories into the agent's context before the first token is generated. This is identical to how a developer would use gstack interactively — the skills appear as context in the conversation. The difference is that Paperclip automates the mounting, scheduling, and lifecycle.

### 6.2 Environment Variables as Task Context

Paperclip injects a set of environment variables into each agent subprocess:

| Variable | Value | Purpose |
|---|---|---|
| `PAPERCLIP_API_URL` | `http://127.0.0.1:3103` | Base URL for all API calls |
| `PAPERCLIP_API_KEY` | (JWT) | Bearer token for API authentication |
| `PAPERCLIP_AGENT_ID` | (UUID) | The running agent's own ID |
| `PAPERCLIP_COMPANY_ID` | (UUID) | The company the agent belongs to |
| `PAPERCLIP_TASK_ID` | (UUID) | The issue assigned for this run |
| `PAPERCLIP_RUN_ID` | (UUID) | The current heartbeat run ID (used in `X-Paperclip-Run-Id` headers) |
| `PAPERCLIP_WAKE_PAYLOAD_JSON` | (JSON) | Compact summary of the issue and recent comments |
| `PAPERCLIP_APPROVAL_ID` | (UUID, if resuming) | The approval the agent should read and act on |

The gstack-bridge skill teaches agents to read these variables first and then call the REST API, rather than relying on session state. This makes every run stateless and resumable.

### 6.3 The Headless Override Pattern

gstack skills were built for interactive sessions with a human in the loop. Paperclip runs are headless — there is no terminal, no `AskUserQuestion` recipient, no user at the keyboard. The integration bridges this gap with a three-tier decision model, defined in `gstack-bridge`:

```
Mechanical decisions  →  Auto-decide using defined defaults
                         (version bump level, stash dirty tree, apply fixes)

Judgment decisions    →  Create Paperclip approval
                         Post question + options as issue comment
                         Set issue to blocked, exit
                         (re-wake on approval with PAPERCLIP_APPROVAL_ID)

Pre-answered          →  Answer is already in the issue description or comments
                         Use it directly, no approval needed
```

This means a human operator can pre-answer checkpoint questions by writing them into the issue description before the run starts. For example, an issue description that says "use MINOR version bump" means the agent never needs to pause and ask.

### 6.4 Cross-Role Delegation vs Inline Skill Chains

gstack skills like `/autoplan` and `/ship` were originally designed to chain multiple roles sequentially within one session (e.g., `/ship` would inline `/review`). Paperclip's async, heartbeat-driven architecture cannot do this — a single agent run cannot block waiting for another agent.

The bridge skill converts these inline chains into async subtask delegation:

| gstack inline chain | Paperclip async equivalent |
|---|---|
| `/ship` invokes `/review` | CTO creates subtask → CTO runs `/review` on that subtask |
| `/autoplan` invokes design review | CEO creates subtask → DesignLead runs `/plan-design-review` |
| `/autoplan` invokes eng review | CEO creates subtask → CTO runs `/plan-eng-review` |
| QALead finds bug | QALead creates subtask → QAEngineer runs `/qa` |

The result is functionally equivalent but asynchronous: the parent agent sets its issue to `in_review` and exits. The child agent runs on the subtask. When the child marks its task done, the parent's next heartbeat picks up the result and continues.

### 6.5 Org Chart as Routing Table

The company's org chart is not just documentation — it is the routing logic. Each agent's `AGENTS.md` defines exactly which task types go to which direct report. The CEO's delegation table:

| Task type | Delegated to |
|---|---|
| Code, bugs, features, PRs, releases | CTO |
| Security audits, vulnerability review | SecurityOfficer |
| UI/UX, design systems, visual work | DesignLead |
| QA oversight, quality reports | QALead |
| Full QA loop (find + fix bugs) | QALead → QAEngineer |
| Cross-functional | Break into per-department subtasks |

Paperclip enforces the `reportsTo` relationships in the database (an agent can only assign subtasks to peers or to agents it manages), while gstack's onboarding files define the semantic routing. Together they create a self-organising system where task structure mirrors org structure.

---

## 7. Infrastructure Fixes Required Before First Success

The first successful end-to-end run required resolving three non-obvious infrastructure issues:

### 7.1 Authentication: `--bare` Flag Interference

**Symptom:** Agent runs failed with *"Not logged in · Please run /login"*

**Root cause:** The CEO agent's `adapterConfig.extraArgs` in the Paperclip database contained `["--bare"]` from a previous experiment. The `--bare` flag bypasses Claude Code's standard authentication flow and requires an explicit `ANTHROPIC_API_KEY`. On subscription-based authentication (where credentials live in `~/.claude/.credentials.json`), `--bare` breaks auth entirely.

**Fix:** `PATCH /api/agents/{id}` with `adapterConfig.extraArgs: []`

The correct endpoint is `/api/agents/:id` — not `/api/companies/:companyId/agents/:id`, which returns 404.

### 7.2 Plugin Isolation: Superpowers Hijacking

**Symptom:** CEO agent ignored all `AGENTS.md`/`CLAUDE.md` instructions and used `TeamCreate` / `SendMessage` instead of curl, creating phantom "figma-integration" teams for an auth task.

**Root cause:** The user's personal Claude Code installation had the `superpowers@superpowers-marketplace` plugin installed in `~/.claude/plugins/`. This plugin injects a `SessionStart` hook into every claude subprocess with the message *"EXTREMELY IMPORTANT — YOU MUST USE THESE SKILLS — THIS IS NOT NEGOTIABLE"*. Because the Paperclip `claude_local` adapter inherits `process.env` and the claude subprocess searches `~/.claude/` for plugins by default, every agent run was hijacked by the superpowers plugin.

**Fix:** Create a clean, plugin-free config directory at `~/.claude-paperclip/` containing only `~/.claude/.credentials.json` and `policy-limits.json` (no plugins, no MCP servers, no hooks). Set `CLAUDE_CONFIG_DIR=C:\Users\simon\.claude-paperclip` on every agent via `adapterConfig.env`.

The `plugins: []` in the agent init log confirms isolation is working.

**Note:** `~/.claude-paperclip/.credentials.json` is a copy, not a symlink (Windows junction limitations). It will become stale when the OAuth token refreshes — periodic re-copy is needed.

### 7.3 Model Capability: Haiku 3 Too Weak

**Symptom:** Haiku 3 agents (`claude-3-haiku-20240307`) ignored multi-step instructions even after plugin isolation. CEO created fictitious TodoWrite entries ("Hire new UX Designer", "Review design engineering tasks") instead of reading its assigned issue. Agent ran into a 80-turn limit calling `Skill: paperclip-create-agent` in an infinite loop.

**Root cause:** `claude-3-haiku-20240307` lacks sufficient instruction-following capability to reliably: (a) read env vars first, (b) choose curl over native tools, and (c) resist the pull of its training on "what a CEO does" when faced with multiple competing signals.

**Fix:** Upgrade all agents to `claude-haiku-4-5-20251001`. With this model, the CEO correctly: checked env vars, called the inbox API, read the issue, listed agents, created subtasks with correct `assigneeAgentId` values, and posted a coordination comment — in a single run, first attempt.

`setup.sh` and `company.json` were updated to use `claude-haiku-4-5-20251001` for all future provisioning.

---

## 8. Automated vs Manual Triggers

An important finding: Paperclip's `assignment` trigger source works immediately. When the CEO created ENGA-2 and assigned it to the CTO, Paperclip automatically woke the CTO within ~60 seconds — before any manual trigger was sent. The same happened for ENGA-3 (SecurityOfficer) and ENGA-4 (QALead).

The heartbeat scheduler also fired automatically:
- CEO heartbeat (`automation` source) re-ran at 08:01 and 08:14 to check for follow-up work on ENGA-1
- SecurityOfficer was woken on ENGA-5 at 08:05 (timed out on that run, but the task remains queued)

This confirms the system is fully autonomous after the initial task injection — no human polling, no manual wakeups required for the delegation cascade.

---

## 9. Current State

```
ENGA-1  [in_progress]  CEO             ← root task, coordinating
  ├─ ENGA-2  [done]    CTO             ← engineering planning complete
  │    ├─ ENGA-5  [todo]  SecurityOfficer   ← security review of backend (queued)
  │    └─ ENGA-6  [todo]  QAEngineer        ← API test suite (queued)
  ├─ ENGA-3  [done]    SecurityOfficer  ← high-level security review complete
  └─ ENGA-4  [todo]    QALead           ← QA oversight (queued)
```

Two issues are complete (ENGA-2, ENGA-3). Four issues remain queued (ENGA-4, 5, 6, and ENGA-1 itself, which closes when all children are done). The heartbeat scheduler will continue processing the remaining tasks autonomously.

---

## 10. What Was Not Tested

This test validated the **delegation and coordination layer** — the Paperclip + gstack-bridge integration. It did not test the full execution of the gstack engineering workflow skills, because no code repository was attached to the task. The following remain to be tested in a follow-up with a real codebase:

| Workflow | Skill chain | Status |
|---|---|---|
| Code review of a real PR | CTO → `/review` → ASK checkpoints → approval flow | Not tested |
| Version bump and PR creation | CTO → `/ship` → delegates to CTO `/review` | Not tested |
| Root-cause debugging | SeniorEngineer → `/investigate` | Not tested |
| Full QA loop with fixes | QAEngineer → `/qa` → commits | Not tested |
| Security audit of code | SecurityOfficer → `/cso` | Not tested |
| Merge, deploy, canary | ReleaseEngineer → `/land-and-deploy` → `/canary` | Not tested |
| Full planning cycle | CEO → `/autoplan` → 4-phase delegation chain | Not tested |
| Human approval checkpoint | Any agent → Paperclip approval → resume | Not tested |

---

## 11. Key Takeaways

1. **Paperclip and gstack compose cleanly.** The `--add-dir` skill mounting mechanism, env-var task context, and REST API for issue management form a coherent contract. gstack skills require no modifications — only the bridge skill is needed to adapt them.

2. **The bridge skill is load-bearing.** Without it, agents fall back to interactive patterns (`AskUserQuestion`, inline role chaining) that break in headless mode. With it, every gstack checkpoint maps cleanly to either an auto-decision or a Paperclip approval.

3. **Assignment-triggered wakeups make the system fast.** Delegation from CEO → CTO happened in under 60 seconds, not at the next scheduled heartbeat. The cascade is near-real-time.

4. **Model capability matters more than prompt engineering.** All the `CLAUDE.md` and `AGENTS.md` instructions in the world could not make `claude-3-haiku-20240307` reliably follow the Paperclip protocol. `claude-haiku-4-5-20251001` followed it correctly on the first attempt. Spending tokens on a capable model is more reliable than spending tokens on additional constraint prompts.

5. **Plugin isolation is essential for headless agents.** Personal IDE plugins (superpowers, Figma, brightdata, etc.) that enhance the interactive developer experience actively harm headless agent runs. A dedicated, clean `CLAUDE_CONFIG_DIR` is a hard requirement for production Paperclip deployments.
