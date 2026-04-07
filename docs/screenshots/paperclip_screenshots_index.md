# Paperclip Engineering Company — Screenshot Index

Captured: 2026-04-07  
Instance: http://localhost:3103  
Total screenshots: 74 PNG files

This document catalogues every screenshot taken of the Paperclip instance running the **Engineering Company** (`ENGA` prefix) with 9 AI agents collaborating on a user authentication feature.

---

## ENG Company (Legacy) — Files 01–11

These pages show the original `ENG` company used for initial setup testing.

| File | URL | Description |
|------|-----|-------------|
| `paperclip_01_*` | `/ENG/dashboard` | ENG company dashboard — early agent activity before ENGA |
| `paperclip_02_*` | `/ENG/issues` | ENG issues list |
| `paperclip_03_*` | `/ENG/agents` | ENG agents list |
| `paperclip_04_*` | `/ENG/skills` | ENG skills library |
| `paperclip_05_*` | `/ENG/org` | ENG org chart |
| `paperclip_06_*` | `/ENG/costs` | ENG costs/spend overview |
| `paperclip_07_*` | `/ENG/activity` | ENG activity log |
| `paperclip_08–11_*` | Various | ENG agent and run detail pages |

---

## CEO Delegation Run — Files 12–31

These pages document the CEO's successful delegation run where it read ENGA-1 and created subtasks for CTO, SecurityOfficer, and QALead.

| File | URL | Description |
|------|-----|-------------|
| `paperclip_12_*` | `/ENGA/agents/ceo/runs/<id>` | CEO run detail — first successful Haiku 4.5 run |
| `paperclip_13_*` | `/ENGA/agents/ceo/runs/<id>` | CEO run — reading inbox and ENGA-1 issue |
| `paperclip_14_*` | `/ENGA/agents/ceo/runs/<id>` | CEO run — listing available agents via curl |
| `paperclip_15_*` | `/ENGA/agents/ceo/runs/<id>` | CEO run — creating ENGA-2 (CTO subtask) |
| `paperclip_16_*` | `/ENGA/agents/ceo/runs/<id>` | CEO run — creating ENGA-3 (SecurityOfficer subtask) |
| `paperclip_17_*` | `/ENGA/agents/ceo/runs/<id>` | CEO run — creating ENGA-4 (QALead subtask) |
| `paperclip_18_*` | `/ENGA/agents/ceo/runs/<id>` | CEO run — posting coordination comment on ENGA-1 |
| `paperclip_19_*` | `/ENGA/issues/ENGA-1` | ENGA-1 issue detail — "Implement user authentication with email/password login" with CEO's coordination comment and 3 subtasks |
| `paperclip_20_*` | `/ENGA/issues/ENGA-2` | ENGA-2 — "Plan and implement email/password authentication backend" assigned to CTO (status: done) |
| `paperclip_21_*` | `/ENGA/issues/ENGA-3` | ENGA-3 — "Security review of authentication implementation" assigned to SecurityOfficer |
| `paperclip_22_*` | `/ENGA/issues/ENGA-4` | ENGA-4 — "QA testing for authentication system" assigned to QALead |
| `paperclip_23_*` | `/ENGA/agents/cto` | CTO agent dashboard — showing ENGA-2 completed run |
| `paperclip_24–27_*` | CTO runs | CTO run details — CTO woke via assignment trigger, created ENGA-5 and ENGA-6 subtasks |
| `paperclip_28_*` | `/ENGA/issues/ENGA-5` | ENGA-5 — "Security Review - Email/Password Authentication Backend" assigned to SecurityOfficer |
| `paperclip_29_*` | `/ENGA/issues/ENGA-6` | ENGA-6 — "QA Testing - Email/Password Authentication API" assigned to QAEngineer |
| `paperclip_30_*` | `/ENGA/agents/securityofficer` | SecurityOfficer agent dashboard — ENGA-5 security audit run |
| `paperclip_31_*` | `/ENGA/agents/qaengineer` | QAEngineer agent dashboard — ENGA-6 QA run |

---

## ENGA Company Pages — Files 32–60

Full walkthrough of every section of the Engineering Company (`ENGA`) in the Paperclip UI.

### Dashboard & Navigation

| File | URL | Description |
|------|-----|-------------|
| `paperclip_32_ENGA_dashboard.png` | `/ENGA/dashboard` | **Main dashboard** — 9 agents enabled, 1 task in progress, $0.43 month spend, 0 pending approvals. Shows live run summaries for QALead, SecurityOfficer, CEO, and QAEngineer cards. Charts: Run Activity, Issues by Priority, Issues by Status, Success Rate |
| `paperclip_47_ENGA_inbox.png` | `/ENGA/inbox` | **Inbox** — 8 unread items showing assignment notifications and issue updates across all agents |
| `paperclip_51_ENGA_issues.png` | `/ENGA/issues` | **Issues list** — all 6 ENGA issues (ENGA-1 through ENGA-6) with status, assignee, and parent/child relationships |
| `paperclip_57_ENGA_new_issue.png` | `/ENGA/issues/new` | **New Issue form** — title, description, assignee, project, priority fields |

### Work: Projects

| File | URL | Description |
|------|-----|-------------|
| `paperclip_58_ENGA_projects.png` | `/ENGA/projects` | **Projects list** — "User Authentication System" project (Email/password authentication backend implementation, backlog) |
| `paperclip_59_ENGA_project_auth_issues.png` | `/ENGA/projects/user-authentication-system/issues` | **Project: User Authentication System** — issues scoped to this project with kanban-style status columns |

### Work: Routines & Goals

| File | URL | Description |
|------|-----|-------------|
| `paperclip_49_ENGA_routines.png` | `/ENGA/routines` | **Routines (Beta)** — scheduled heartbeat triggers for each agent (CEO: 30min, engineers: on-demand) |
| `paperclip_50_ENGA_goals.png` | `/ENGA/goals` | **Goals** — company-level goals tracking page |

### Company: Org, Skills, Costs, Activity

| File | URL | Description |
|------|-----|-------------|
| `paperclip_56_ENGA_org.png` | `/ENGA/org` | **Org chart** — visual hierarchy: CEO at top, CTO/QALead/SecurityOfficer/DesignLead reporting to CEO, SeniorEngineer/ReleaseEngineer/DevExEngineer under CTO, QAEngineer under QALead |
| `paperclip_55_ENGA_skills.png` | `/ENGA/skills` | **Skills library** — all imported gstack skills (ship, review, qa, qa-only, cso, investigate, etc.) plus paperclip and gstack-bridge skills |
| `paperclip_52_ENGA_costs.png` | `/ENGA/costs` | **Costs** — token usage and spend breakdown per agent, model cost rates |
| `paperclip_53_ENGA_activity.png` | `/ENGA/activity` | **Activity log** — chronological feed of all agent runs, issue creations, status changes, comments |

### Settings

| File | URL | Description |
|------|-----|-------------|
| `paperclip_60_ENGA_company_settings.png` | `/ENGA/company/settings` | **Company settings** — company name, prefix (ENGA), budget limits, general configuration |
| `paperclip_54_instance_settings.png` | `/instance/settings/general` | **Instance settings** — global Paperclip instance configuration (model defaults, API keys, scheduler settings) |

### Agents List

| File | URL | Description |
|------|-----|-------------|
| `paperclip_48_ENGA_agents_list.png` | `/ENGA/agents` | **All agents** — grid/list of all 9 agents with role, status, last active time |

---

## CEO Agent Detail — Files 33–46

Deep dive into the CEO agent's configuration and history.

| File | URL | Description |
|------|-----|-------------|
| `paperclip_33–41_ENGA_ceo_*.png` | `/ENGA/agents/ceo/dashboard` | **CEO dashboard** — current status, recent runs, assigned issues (ENGA-1 in_progress) |
| `paperclip_42_ENGA_ceo_instructions.png` | `/ENGA/agents/ceo/instructions` | **CEO instructions tab** — AGENTS.md content displayed in editor: delegation rules, banned tools (TeamCreate/SendMessage/TodoWrite), curl-based API protocol |
| `paperclip_43_ENGA_ceo_skills.png` | `/ENGA/agents/ceo/skills` | **CEO skills tab** — assigned skills: paperclip, gstack-bridge, gstack-autoplan, gstack-plan-ceo-review, gstack-office-hours |
| `paperclip_44_ENGA_ceo_configuration.png` | `/ENGA/agents/ceo/configuration` | **CEO configuration tab** — adapter: claude_local, model: claude-haiku-4-5-20251001, env vars including CLAUDE_CONFIG_DIR=~/.claude-paperclip |
| `paperclip_45_ENGA_ceo_runs.png` | `/ENGA/agents/ceo/runs` | **CEO runs history** — list of all runs with timestamps, trigger source (timer/on_demand/assignment), token counts, success/failure |
| `paperclip_46_ENGA_ceo_budget.png` | `/ENGA/agents/ceo/budget` | **CEO budget tab** — per-agent spend limits and current month usage |

---

## All Agent Dashboards — Files 61–68

| File | URL | Description |
|------|-----|-------------|
| `paperclip_61_ENGA_cto_dashboard.png` | `/ENGA/agents/cto` | **CTO dashboard** — completed ENGA-2, created ENGA-5 (security) and ENGA-6 (QA) subtasks |
| `paperclip_62_ENGA_seniorengineer_dashboard.png` | `/ENGA/agents/seniorengineer` | **SeniorEngineer dashboard** — ENGA-1 assigned (in_progress), implementation work ongoing |
| `paperclip_63_ENGA_securityofficer_dashboard.png` | `/ENGA/agents/securityofficer` | **SecurityOfficer dashboard** — ENGA-3 and ENGA-5 both assigned (security review tasks) |
| `paperclip_64_ENGA_qalead_dashboard.png` | `/ENGA/agents/qalead` | **QALead dashboard** — ENGA-4 assigned (QA oversight), delegation to QAEngineer visible |
| `paperclip_65_ENGA_qaengineer_dashboard.png` | `/ENGA/agents/qaengineer` | **QAEngineer dashboard** — ENGA-6 assigned (hands-on QA testing run completed) |
| `paperclip_66_ENGA_designlead_dashboard.png` | `/ENGA/agents/designlead` | **DesignLead dashboard** — no tasks assigned in this test run (UI/design work not triggered) |
| `paperclip_67_ENGA_devexengineer_dashboard.png` | `/ENGA/agents/devexengineer` | **DevExEngineer dashboard** — no tasks assigned in this test run |
| `paperclip_68_ENGA_releaseengineer_dashboard.png` | `/ENGA/agents/releaseengineer` | **ReleaseEngineer dashboard** — no tasks assigned in this test run (deploy not yet triggered) |

---

## Issue Detail Pages — Files 69–74

Full delegation chain: 1 root issue → 5 delegated subtasks across 4 agents.

| File | URL | Description |
|------|-----|-------------|
| `paperclip_69_ENGA_issue_1.png` | `/ENGA/issues/ENGA-1` | **ENGA-1** (root) — "Implement user authentication with email/password login" — assigned to SeniorEngineer, status: in_progress. Contains CEO's coordination comment and links to ENGA-2/3/4 subtasks |
| `paperclip_70_ENGA_issue_2.png` | `/ENGA/issues/ENGA-2` | **ENGA-2** — "Plan and implement email/password authentication backend" — assigned to CTO, parent: ENGA-1, status: **done** |
| `paperclip_71_ENGA_issue_3.png` | `/ENGA/issues/ENGA-3` | **ENGA-3** — "Security review of authentication implementation" — assigned to SecurityOfficer, parent: ENGA-1 (CEO-created), status: todo |
| `paperclip_72_ENGA_issue_4.png` | `/ENGA/issues/ENGA-4` | **ENGA-4** — "QA testing for authentication system" — assigned to QALead, parent: ENGA-1 (CEO-created), status: todo |
| `paperclip_73_ENGA_issue_5.png` | `/ENGA/issues/ENGA-5` | **ENGA-5** — "Security Review - Email/Password Authentication Backend" — assigned to SecurityOfficer, parent: ENGA-2 (CTO-created), status: todo |
| `paperclip_74_ENGA_issue_6.png` | `/ENGA/issues/ENGA-6` | **ENGA-6** — "QA Testing - Email/Password Authentication API" — assigned to QAEngineer, parent: ENGA-2 (CTO-created), status: todo |

---

## Delegation Tree

```
ENGA-1: Implement user authentication          [CEO → SeniorEngineer, in_progress]
├── ENGA-2: Plan & implement auth backend      [CEO → CTO, done]
│   ├── ENGA-5: Security Review - Auth Backend [CTO → SecurityOfficer, todo]
│   └── ENGA-6: QA Testing - Auth API          [CTO → QAEngineer, todo]
├── ENGA-3: Security review of auth impl       [CEO → SecurityOfficer, todo]
└── ENGA-4: QA testing for auth system         [CEO → QALead, todo]
```

All delegations were made autonomously by agents reading Paperclip's REST API via curl — no `TeamCreate`, `SendMessage`, or other Claude tool calls were used.

---

## Key Metrics (from dashboard screenshot)

| Metric | Value |
|--------|-------|
| Agents enabled | 9 |
| Tasks in progress | 1 (4 open, 0 blocked) |
| Month spend | $0.43 |
| Pending approvals | 0 |
| Total issues created | 6 |
| Agents that ran | 5 of 9 (CEO, CTO, SecurityOfficer, QALead, QAEngineer) |
| Model used | claude-haiku-4-5-20251001 |
