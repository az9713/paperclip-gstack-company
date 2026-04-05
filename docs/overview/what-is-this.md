# What Is This?

This repository is a production template for an **autonomous engineering team** — nine AI agents that collaborate to plan, implement, review, ship, and monitor software. You create a task, assign it to the CEO agent, and the team handles the rest: delegating work, writing code, running QA, and creating pull requests, with human approval checkpoints at the decisions that matter.

The mental model in one sentence: **Paperclip gives agents their jobs. gstack gives agents their skills.**

---

## The Three Parts

### Paperclip

Paperclip (`paperclip/`) is an open-source Node.js server that orchestrates a team of AI agents. It models a company with an org chart: agents have roles, titles, reporting lines, and budgets. Work flows through a ticket system — issues with statuses, priorities, parent/child relationships, and assignees.

Paperclip does not care which AI model runs your agents. It provides the infrastructure: heartbeat scheduling (agents wake on a cron schedule, check their inbox, act), an approval system (humans can review and approve agent decisions before work proceeds), budget enforcement (monthly spend limits per agent), and session continuity (agents resume the same Claude Code session across heartbeats rather than starting fresh each time).

The primary adapter for the Engineering Company template is `claude_local`, which runs Claude Code via `claude --print - --output-format stream-json --verbose --dangerously-skip-permissions`. Paperclip mounts skills into Claude's skill directory before each run, then tears them down after.

### gstack

gstack (`gstack/`) is an open-source engineering skills framework created by Garry Tan. It gives Claude Code (and other AI agents) a set of opinionated slash commands called "skills": `/review`, `/ship`, `/qa`, `/qa-only`, `/investigate`, `/autoplan`, `/land-and-deploy`, `/canary`, `/cso`, `/devex-review`, `/benchmark`, `/retro`, `/document-release`, `/design-*`, `/plan-*-review`, `/careful`, `/guard`, `/codex`, and others.

Each skill is a SKILL.md file — a structured prompt that teaches the agent how to perform a role-specific engineering workflow with checklists, quality gates, and interactive checkpoints. Skills are designed to be invoked interactively: they pause at judgment-call moments and ask the human (`AskUserQuestion`) for decisions before proceeding.

gstack also ships a headless Chromium daemon (`$B` commands) for skills that need web interaction — running QA test flows, taking screenshots, verifying deployments.

### The Engineering Company

The Engineering Company (`companies/engineering/`) is a template that wires Paperclip and gstack together. It defines a 9-agent team where each agent is provisioned with role-specific gstack skills. The key integration challenge: gstack skills use `AskUserQuestion` for human checkpoints, but Paperclip runs Claude headlessly — there is no terminal to respond to.

The solution is the **`gstack-bridge` skill** (`companies/engineering/skills/gstack-bridge/`). This custom skill is mounted alongside the gstack skills for every agent. It teaches agents how to operate gstack skills in Paperclip's headless mode: auto-deciding mechanical checkpoints, converting judgment checkpoints into Paperclip approvals that humans approve via the web UI, and delegating cross-role phases as subtasks to the appropriate specialist agents.

---

## The Org Chart

```
Human (Board Operator)
└── CEO                  (claude-opus-4-6, every 15 min)
    ├── CTO              (claude-sonnet-4-6, every 20 min)
    │   ├── SeniorEngineer    (claude-sonnet-4-6, every 30 min)
    │   ├── ReleaseEngineer   (claude-sonnet-4-6, every 30 min)
    │   └── DevExEngineer     (claude-sonnet-4-6, hourly)
    ├── QALead           (claude-sonnet-4-6, every 4 hours)
    │   └── QAEngineer        (claude-sonnet-4-6, every 30 min)
    ├── SecurityOfficer  (claude-sonnet-4-6, every 6 hours)
    └── DesignLead       (claude-sonnet-4-6, every 30 min)
```

| Agent | gstack Skills |
|-------|--------------|
| CEO | `/autoplan`, `/plan-ceo-review`, `/office-hours` |
| CTO | `/plan-eng-review`, `/review`, `/ship` |
| SeniorEngineer | `/investigate`, `/codex` |
| ReleaseEngineer | `/land-and-deploy`, `/canary`, `/document-release`, `/setup-deploy` |
| DevExEngineer | `/devex-review`, `/plan-devex-review`, `/retro`, `/benchmark` |
| QALead | `/qa-only` |
| QAEngineer | `/qa` |
| SecurityOfficer | `/cso`, `/careful`, `/guard` |
| DesignLead | `/design-review`, `/design-html`, `/design-consultation`, `/design-shotgun`, `/plan-design-review` |

Every agent also receives the `paperclip` skill (Paperclip's own API documentation) and the `gstack-bridge` skill (headless operation rules).

---

## How a Task Flows

A typical feature task — say, "Build user authentication with OAuth2" — flows like this:

1. **Human creates the issue** in Paperclip, assigns it to the CEO.
2. **CEO wakes** on its next heartbeat (up to 15 minutes), reads the task, and creates subtasks delegating implementation to the CTO and QA overview to QALead.
3. **CTO wakes**, delegates implementation to SeniorEngineer and queues a review subtask for itself.
4. **SeniorEngineer wakes**, runs `/investigate` (if the codebase needs analysis first), then `/codex` to implement the feature. Marks the subtask `in_review`.
5. **CTO wakes**, runs `/review` on the SeniorEngineer's branch. If there are ASK items (judgment-call issues), CTO creates a Paperclip approval and blocks the task. The human approves from the UI. CTO resumes, then runs `/ship` to create the PR.
6. **ReleaseEngineer wakes**, runs `/land-and-deploy` to merge and deploy. At the pre-merge gate, always creates a Paperclip approval. Human approves. Deploy proceeds.
7. **QALead wakes**, runs `/qa-only` to generate a bug report. If bugs are found, creates subtasks for QAEngineer.
8. **QAEngineer wakes**, runs `/qa` to find, fix, and verify bugs atomically.

At each step, the human's role is: approve checkpoint decisions that require judgment, review comments on tasks, and optionally intervene if something goes wrong.

---

## What Each Part Owns

| Concern | Owned by |
|---------|----------|
| Agent scheduling, task management, budgets | Paperclip |
| Engineering skill workflows and quality gates | gstack |
| Org chart, agent roles, skill assignments | Engineering Company template |
| Headless/interactive bridge | `gstack-bridge` skill |
| Human oversight checkpoints | Paperclip approval system |

For further reading:
- [Key Concepts](key-concepts.md) — glossary of every important term
- [gstack Skills](../concepts/gstack-skills.md) — deep dive into how skills work
- [Paperclip Platform](../concepts/paperclip-platform.md) — deep dive into orchestration
- [Bridge Skill](../concepts/bridge-skill.md) — how the integration layer works
