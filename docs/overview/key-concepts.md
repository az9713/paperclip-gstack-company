# Key Concepts

A reference glossary for every important term in the gstack + Paperclip + Engineering Company codebase. Entries are organized by layer.

---

## Paperclip Platform

### Company

A Paperclip Company is the top-level organizational unit. It contains agents, issues, skills, goals, and budgets. All data is company-scoped — one Paperclip deployment can run multiple companies with complete isolation between them. Each company has a name and an `issuePrefix` (e.g., `ENG`) used to prefix issue identifiers.

**Example:** The Engineering Company template creates a company called "Engineering Co" with prefix `ENG`. Issues appear as `ENG-1`, `ENG-2`, etc.

### Agent

An Agent is an AI worker with a role, title, reporting line (reportsTo), capabilities description, and an adapter that determines how it runs. Agents are assigned issues (tasks) and wake on a heartbeat schedule to work them. Each agent has a `budgetMonthlyCents` cap — when reached, the agent stops spending until the next month.

**Example:** The CEO agent has role `ceo`, title "Chief Executive Officer", no `reportsTo` (it is the top of the org chart), and a heartbeat schedule of `*/15 * * * *` (every 15 minutes).

### Issue / Task

Issues and tasks are used interchangeably in this codebase. An Issue is a unit of work with a title, description, status, priority, assignee (agent or human), and optionally a parent issue. Issues flow through the lifecycle: `backlog` → `todo` → `in_progress` → `in_review` → `done`. They can also be `blocked` (waiting for human input) or `cancelled`.

**Example:** When the CEO delegates implementation work to the CTO, it creates a child issue with `parentId` set to the CEO's issue and `assigneeAgentId` set to the CTO's ID.

### Heartbeat

A Heartbeat is a scheduled wake event that causes an agent to run. Each agent has a `heartbeat.schedule` configured as a cron expression. When the schedule fires, Paperclip starts a new run for the agent, injecting the wake context (what issue it should work on, why it was woken). After the run completes, the agent sleeps until the next heartbeat.

**Example:** The CEO has schedule `*/15 * * * *` — it wakes every 15 minutes to check its inbox for new tasks. The SecurityOfficer has `0 */6 * * *` — it wakes every 6 hours because security audits are less time-sensitive.

### Approval

An Approval is a human decision request created by an agent when it cannot proceed without guidance. Approvals have a type (e.g., `gstack_checkpoint`, `hire_agent`, `approve_ceo_strategy`), a payload describing the decision, and a status that flows from `pending` → `approved`, `rejected`, or `revision_requested`. When an approval is resolved, Paperclip wakes the requesting agent with the `PAPERCLIP_APPROVAL_ID` environment variable set so the agent can fetch the decision and continue.

**Example:** The CTO runs `/review` and finds two judgment-call issues (ASK items). It creates a `gstack_checkpoint` approval listing both items with options A/B, posts the question as an issue comment, sets the issue to `blocked`, and exits. The human approves option A in the UI. Paperclip re-wakes the CTO with `--resume <sessionId>` and `PAPERCLIP_APPROVAL_ID=<id>`.

### Adapter

An Adapter is the runtime that executes an agent's code. The primary adapter for the Engineering Company is `claude_local`, which runs Claude Code via `claude --print - --output-format stream-json --verbose`. Other adapters exist for Codex, Gemini, Cursor, and custom HTTP endpoints. The adapter is responsible for injecting environment variables, mounting skills, managing the process lifecycle, and parsing output.

**Example:** The `claude_local` adapter builds an ephemeral skill directory with symlinks to the agent's desired skills, then invokes `claude --print - --output-format stream-json --verbose --dangerously-skip-permissions --add-dir <skillsDir> --resume <sessionId>`.

### Session / `--resume`

Session continuity means an agent can resume the same Claude Code conversation context across multiple runs. The `claude_local` adapter extracts the `sessionId` from Claude's output after the first run and stores it. On subsequent runs, it passes `--resume <sessionId>`. This means the agent remembers what it was doing and does not need to re-read all context from scratch on every heartbeat.

**Example:** The CTO starts implementing a review, is interrupted by a timeout, and wakes again. With `--resume`, it continues where it left off without re-reading the entire PR diff.

### Budget

Budget tracking in Paperclip monitors API token spend per agent. Each agent has a `budgetMonthlyCents` limit. Spend is tracked via billing events. When an agent hits its limit, runs are blocked until the budget resets at the start of the next calendar month. This prevents runaway agent loops from consuming unbounded API spend.

**Example:** An agent configured with `budgetMonthlyCents: 5000` has a $50/month budget. If it burns through this — e.g., due to a high-turn debugging loop — Paperclip stops scheduling runs until the month rolls over.

### Checkout

Checkout is an atomic operation that marks an issue as claimed by the current run. `POST /api/issues/{id}/checkout` returns `200` if the claim succeeded, or `409 Conflict` if another run already has it. Agents should always checkout before working on an issue and skip `409` responses (meaning another instance is already handling it).

**Example:** The CEO's heartbeat fires. It calls checkout on issue `ENG-1`. If it gets `409`, it means a previous run of the CEO is already working that issue and this run should skip it.

### Wake Context

The Wake Context is the payload Paperclip injects into each agent run to tell the agent why it was woken and what to work on. It is delivered via the `PAPERCLIP_WAKE_PAYLOAD_JSON` environment variable (a compact JSON summary) and via the `PAPERCLIP_WAKE_REASON` and `PAPERCLIP_TASK_ID` variables. The bridge skill uses this to identify the current task before doing anything else.

**Example:** A wake payload might contain `wakeReason: "approval_resolved"`, `taskId: "issue-uuid-123"`, and `approvalId: "approval-uuid-456"`, telling the agent it was woken because a human just approved its checkpoint.

---

## gstack

### Skill

A Skill is a gstack engineering workflow defined as a SKILL.md file. Each skill teaches an AI agent how to perform a specific role — code review, QA testing, security audit, etc. — with step-by-step checklists, quality gates, and decision points. Skills are mounted into Claude Code's skill directory via `--add-dir` and invoked with slash commands (e.g., `/review`, `/qa`).

**Example:** The `/review` skill teaches the CTO how to perform a pre-landing code review: check for performance issues, security problems, type errors, and code quality. It categorizes findings as AUTO-FIX (apply without asking) or ASK (ask the human before applying).

### SKILL.md

SKILL.md is the file format for a gstack skill. It has YAML frontmatter (name, description, allowed-tools, preamble-tier) followed by the skill body — a Markdown prompt that Claude reads and follows. Most SKILL.md files in gstack are auto-generated from `.tmpl` template files using `bun run gen:skill-docs`. Never edit SKILL.md files directly in gstack — edit the `.tmpl` file instead.

**Example:** `gstack/review/SKILL.md` starts with frontmatter declaring `name: review` and `allowed-tools: [Bash, Read, Write, Edit]`, followed by 200+ lines of structured workflow instructions.

### Checkpoint

A Checkpoint is a pause point within a gstack skill where the agent needs a human decision before continuing. Interactive gstack (used directly with Claude Code) calls `AskUserQuestion` at checkpoints. In Paperclip headless mode, the `gstack-bridge` skill intercepts these and either auto-decides (for mechanical choices) or creates a Paperclip approval (for judgment calls).

**Example:** The `/land-and-deploy` skill always creates a checkpoint at the pre-merge readiness gate — it shows a summary of test results, diff size, and reviewer approval status, then asks the human to confirm before merging.

### AUTO-FIX vs ASK

These are the two categories of review findings in the `/review` skill. AUTO-FIX items (dead code, N+1 queries, stale comments, type safety issues) are always applied without asking. ASK items are judgment calls — the agent presents them with options and waits for human input. In Paperclip mode, ASK items trigger a `gstack_checkpoint` approval.

**Example:** If `/review` finds a security vulnerability (ASK item) and a stale TODO comment (AUTO-FIX item), it applies the TODO fix automatically and creates an approval asking whether to patch the security issue or leave it for a dedicated security PR.

### ETHOS Preamble

The ETHOS Preamble is a block of builder philosophy that gstack injects into every skill's preamble at generation time. It establishes three principles: Boil the Lake (do the complete thing when AI makes marginal cost near-zero), Search Before Building (check what exists before designing from scratch), and User Sovereignty (AI recommends, users decide). These shape how agents reason throughout every skill.

**Example:** Because of "Boil the Lake", the `/review` skill always recommends full test coverage rather than suggesting to defer tests to a follow-up PR.

### Skill Chain

A Skill Chain is when one gstack skill invokes other skills as part of its workflow. `/autoplan` is the primary example: it chains CEO review → design review → engineering review → DX review in sequence. In interactive mode, all phases run in the same Claude Code session. In Paperclip mode, each cross-role phase is delegated as a subtask to the appropriate specialist agent.

**Example:** When the CEO runs `/autoplan`, it completes its own CEO review phase, then creates a subtask for DesignLead to run `/plan-design-review`, another for CTO to run `/plan-eng-review`, and a third for DevExEngineer to run `/plan-devex-review`.

---

## Engineering Company Integration

### Bridge Skill

The Bridge Skill (`gstack-bridge`) is a custom skill specific to the Engineering Company template. It teaches agents how to operate gstack skills in Paperclip's headless execution mode. Every agent loads it first before invoking any other gstack skill. It defines three behaviors: auto-decide for mechanical checkpoints, create Paperclip approvals for judgment checkpoints, and delegate cross-role phases as subtasks.

**Example:** Before running `/review`, the CTO reads the `gstack-bridge` skill. When `/review` would normally call `AskUserQuestion` for ASK items, the bridge skill instructs the agent to call `POST /api/companies/{id}/approvals` with type `gstack_checkpoint` instead.

### Onboarding Bundle

An Onboarding Bundle is the set of Markdown files in `companies/engineering/onboarding/{agent-key}/` that define an agent's persona, delegation rules, and per-heartbeat checklist. The bundle is mounted as an `onboardingDir` in the agent's adapter config. Every agent has at minimum an AGENTS.md (role definition and delegation rules); the CEO also has HEARTBEAT.md (what to do each wake) and SOUL.md (persona).

**Example:** The CEO's onboarding bundle at `onboarding/ceo/` contains AGENTS.md (role, skills, delegation table), HEARTBEAT.md (7-step checklist for each heartbeat), and SOUL.md (strategic voice and decision style).

### Delegation

Delegation is the pattern where an agent creates a child issue assigned to another agent rather than doing the work itself. The parent issue waits in `in_review` status while the child issue is worked. When the child is done, the parent agent resumes on the next heartbeat and continues with the results.

**Example:** The CTO delegates feature implementation to SeniorEngineer by creating a child issue with `parentId: <cto-task-id>` and `assigneeAgentId: <senior-eng-id>`. The CTO sets its own task to `in_review` and waits. When SeniorEngineer completes the work and comments, CTO picks up the next heartbeat.

### `gstack_checkpoint` Approval Type

`gstack_checkpoint` is the Paperclip approval type registered specifically for gstack skill checkpoints. It is defined in `paperclip/packages/shared/src/constants.ts` alongside the built-in types (`hire_agent`, `approve_ceo_strategy`, `budget_override_required`). The approval payload contains the skill name, step name, question, options array, recommendation, and context.

**Example:** An approval of type `gstack_checkpoint` with payload `{skill: "review", step: "ASK items", question: "Fix security issue in auth middleware?", options: [{key: "A", label: "Fix it now"}, {key: "B", label: "File separate security PR"}]}` appears in the Paperclip approvals UI for a human to resolve.
