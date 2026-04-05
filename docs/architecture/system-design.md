# System Design

The technical architecture of the gstack + Paperclip + Engineering Company system.

---

## Three-Layer Architecture

The system is built in three distinct layers with minimal coupling between them:

```
┌─────────────────────────────────────────────────┐
│           Engineering Company Template           │
│  company.json, setup.sh, onboarding bundles,    │
│  gstack-bridge skill, agent configurations       │
└────────────────────┬────────────────────────────┘
                     │ uses
┌────────────────────▼────────────────────────────┐
│              Paperclip Platform                  │
│  Company model, org chart, issue lifecycle,      │
│  heartbeats, approvals, budgets, adapters,       │
│  session continuity, web UI, REST API            │
└──────────┬──────────────────────────────────────┘
           │ mounts via --add-dir
┌──────────▼──────────────────────────────────────┐
│              gstack Skills                       │
│  SKILL.md files, ETHOS preamble, workflows,      │
│  quality gates, checkpoint definitions,          │
│  headless browser ($B commands)                  │
└─────────────────────────────────────────────────┘
```

Each layer is independently useful:
- gstack works standalone with Claude Code without Paperclip
- Paperclip works with any agent (Codex, Gemini, custom HTTP) without gstack
- The Engineering Company template integrates them; changing it does not require changes to either underlying system

---

## Skill Mounting: Ephemeral Temp Directories

The `claude_local` adapter creates a fresh, ephemeral skill directory for every run:

```
1. adapter creates /tmp/paperclip-skills-abc123/
2. adapter creates /tmp/paperclip-skills-abc123/.claude/skills/
3. For each desired skill:
   symlink: /tmp/paperclip-skills-abc123/.claude/skills/<runtimeName>
          → /absolute/path/to/skill/source/dir
4. claude invoked with: --add-dir /tmp/paperclip-skills-abc123
5. Claude Code discovers .claude/skills/ inside the added dir
6. Claude Code registers each subdirectory as a skill (slash command)
7. Run completes
8. Temp directory is cleaned up
```

The `runtimeName` is the directory name that Claude Code sees — it becomes the slash command name. For a skill with `name: review` in its frontmatter, the runtimeName is `review` and the command is `/review`.

The `desiredSkills` list in the agent's config controls which skills get symlinked for that agent. Each agent gets exactly its configured skills — no cross-contamination between agent configs.

**Why ephemeral?** This ensures each run starts with a clean state and the correct skill set. It also means skill source paths can change (e.g., when you update a skill file) and the change is immediately effective on the next run without any cache invalidation.

---

## Session Continuity: `--resume <sessionId>`

Session continuity keeps Claude Code's conversation context alive across multiple Paperclip runs.

```
Run 1 (first heartbeat for task ENG-7):
  → claude --print - --output-format stream-json ... <prompt>
  ← JSON stream containing: { "session_id": "abc123", ... }
  → Paperclip stores: agentTaskSessions[agentId + taskId + cwd] = "abc123"

Run 2 (second heartbeat, same task):
  → claude --print - --output-format stream-json --resume abc123 ... <prompt>
  ← Claude restores conversation context: tool call history, read files, prior reasoning
  ← Agent continues where it left off without re-reading everything
```

**Session matching:** The stored session ID is used only when the current run's `cwd` matches the cwd when the session was created. If the working directory changes (new workspace, different branch), a new session starts.

**Session expiry:** Claude Code sessions can expire. If `--resume <sessionId>` fails with a session-not-found error, Paperclip falls back to starting a new session. The agent starts fresh but still has the task's full context from the Paperclip API.

**The critical use case — approvals:** When an agent creates a checkpoint approval and exits, its session ID is saved. When Paperclip re-wakes the agent after the human approves, it passes `--resume <sessionId>`. The agent resumes with full context — it knows which skill it was running, which step it was on, what it had already done. The approval's answer is delivered via `PAPERCLIP_APPROVAL_ID` which the bridge skill uses to fetch the decision and continue.

---

## The Approval Wake Loop

The approval → wake → resume cycle is the core human-in-the-loop mechanism:

```
1. Agent hits judgment checkpoint
2. Agent: POST /api/companies/{id}/approvals  → approval.id
3. Agent: PATCH /api/issues/{id}  { status: "blocked" }
4. Agent exits run
5. Paperclip: approval stored as pending, session ID preserved

   [time passes — human opens Paperclip UI]

6. Human reviews approval question and options
7. Human: PATCH /api/approvals/{id}  { status: "approved", decisionNote: "Option B..." }
8. Paperclip: approval marked resolved
9. Paperclip: generates wakeup event for requestedByAgentId
   wakeReason: "approval_resolved"
   approvalId: <id>
   approvalStatus: "approved"

10. Agent's next heartbeat fires (or immediate wake if Paperclip supports it)
11. Claude launched with: --resume <sessionId>
    env: PAPERCLIP_APPROVAL_ID=<id>
         PAPERCLIP_WAKE_REASON=approval_resolved
12. Agent reads gstack-bridge → detects PAPERCLIP_APPROVAL_ID
13. Agent: GET /api/approvals/{PAPERCLIP_APPROVAL_ID}
14. Agent reads status + decisionNote
15. Agent continues gstack skill from where it left off
16. Agent: PATCH /api/issues/{id}  { status: "in_progress" }
```

The session ID is the key that makes step 15 work — Claude Code restores full prior context via `--resume`, so the agent does not need to re-read everything to know where it was.

---

## The Async Delegation Model

Task delegation between agents is **asynchronous**, not synchronous. There are no direct agent-to-agent calls. Everything flows through Paperclip's issue system.

```
CEO heartbeat fires:
  CEO reads task ENG-1
  CEO creates subtask ENG-2 (assignee: CTO)
  CEO sets ENG-1 to in_review
  CEO exits

  [up to 20 minutes pass]

CTO heartbeat fires:
  CTO reads inbox → finds ENG-2
  CTO checkouts ENG-2
  CTO works ENG-2
  CTO sets ENG-2 to done
  CTO exits

  [up to 15 minutes pass]

CEO heartbeat fires:
  CEO sees ENG-2 is done (child of ENG-1)
  CEO resumes work on ENG-1
```

The consequence: the total wall-clock time for a multi-agent task is the sum of the maximum heartbeat delays for each agent in the chain, plus the actual work time at each step. A task requiring CEO → CTO → SeniorEngineer → CTO could take 15 + 20 + 30 + 20 = 85 minutes of delay even if each agent does 5 minutes of actual work.

This is a deliberate architectural choice (see [ADR 002](adr/002-multi-agent-not-single-agent.md)). The async model enables parallel work: while the CTO is reviewing one PR, the SecurityOfficer is auditing another module, and the QAEngineer is fixing bugs — all simultaneously.

---

## Data Flow: Human Creates Issue → Work Gets Done

```
Human creates issue ENG-1 (assigned to CEO)
    │
    ▼
Paperclip stores ENG-1 in database (status: todo)
    │
    ▼ (heartbeat fires, up to 15 min)
CEO run starts
    ├── reads PAPERCLIP_WAKE_PAYLOAD_JSON
    ├── reads gstack-bridge skill
    ├── reads CEO onboarding bundle (AGENTS.md, HEARTBEAT.md)
    ├── calls POST /api/issues/{id}/checkout (ENG-1)
    ├── analyzes task → decides to delegate
    ├── creates ENG-2 (assignee: CTO, parentId: ENG-1)
    ├── PATCH ENG-1 → status: in_review
    └── posts comment, exits
    │
    ▼ (heartbeat fires, up to 20 min)
CTO run starts
    ├── reads task ENG-2 context
    ├── reads gstack-bridge skill
    ├── reads CTO onboarding bundle
    ├── checkouts ENG-2
    ├── creates ENG-3 (assignee: SeniorEngineer, parentId: ENG-2)
    ├── PATCH ENG-2 → status: in_review
    └── exits
    │
    ▼ (heartbeat fires, up to 30 min)
SeniorEngineer run starts
    ├── reads ENG-3 context
    ├── reads gstack-bridge skill
    ├── checkouts ENG-3
    ├── runs /investigate + /codex
    ├── writes code, commits (Co-Authored-By: Paperclip <noreply@paperclip.ing>)
    ├── PATCH ENG-3 → status: in_review
    └── posts "implementation complete on branch feature/xxx", exits
    │
    ▼ (heartbeat fires, up to 20 min)
CTO run starts
    ├── sees ENG-3 is in_review
    ├── runs /review on feature/xxx
    ├── finds ASK item (judgment checkpoint)
    ├── POST /api/companies/{id}/approvals (gstack_checkpoint)
    ├── POST /api/issues/{id}/comments (checkpoint question)
    ├── PATCH ENG-2 → status: blocked
    └── exits
    │
    ▼ (human opens Paperclip UI)
Human reviews approval
    ├── reads question: "Fix SQL injection inline or defer?"
    └── PATCH /api/approvals/{id} → status: approved, decisionNote: "Fix inline"
    │
    ▼ (wake event generated)
CTO run resumes (--resume <sessionId>, PAPERCLIP_APPROVAL_ID set)
    ├── reads gstack-bridge → detects PAPERCLIP_APPROVAL_ID → Resume Protocol
    ├── GET /api/approvals/{id} → "approved: Fix inline"
    ├── continues /review → applies fix, review passes
    ├── runs /ship → bumps version, creates PR
    ├── creates ENG-5 (assignee: ReleaseEngineer, parentId: ENG-2)
    ├── PATCH ENG-2 → in_review
    └── exits
    │
    ▼ ... and so on for deploy, QA, security audit
```

---

## How the `--add-dir` Mechanism Works

`--add-dir` is a Claude Code CLI flag that adds a directory to Claude's file discovery scope. Claude Code looks for `.claude/skills/` within any directory added via `--add-dir`.

The Paperclip adapter exploits this:

```bash
# What Paperclip builds:
/tmp/paperclip-skills-abc123/
└── .claude/
    └── skills/
        ├── review -> /path/to/gstack/review    (symlink)
        ├── qa -> /path/to/gstack/qa             (symlink)
        └── gstack-bridge -> /path/to/skills/gstack-bridge  (symlink)

# What it invokes:
claude --print - --output-format stream-json --verbose \
  --dangerously-skip-permissions \
  --add-dir /tmp/paperclip-skills-abc123 \
  --resume <sessionId> \
  < prompt
```

Claude Code sees the temp directory as a project context directory and discovers the `.claude/skills/` inside it. Each symlink target (the actual skill directory) contains a `SKILL.md` file. Claude Code registers them as slash commands.

This is the same mechanism gstack uses for its standard `./setup` installation — the only difference is that Paperclip creates it fresh each run as a temp directory rather than installing it permanently.

---

## Concurrency Safety

Two agent runs for the same issue could fire simultaneously (e.g., if a heartbeat is delayed and two fire close together). The checkout pattern prevents duplicate work:

- First run calls `POST /api/issues/{id}/checkout` → `200 OK`
- Second run calls `POST /api/issues/{id}/checkout` → `409 Conflict`
- Second run sees `409`, skips the issue, exits

The checkout is released automatically when the run ends. This is atomic at the database level — Paperclip uses PostgreSQL transactions to ensure exactly-once checkout semantics.

Budget enforcement uses the same atomic pattern. Token spend is tracked with database-level locks to prevent two simultaneous runs from both spending the remaining budget.
