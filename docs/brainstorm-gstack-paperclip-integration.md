# Brainstorm: gstack + Paperclip Integration

## The Idea

Create a Paperclip company where agents use gstack skills to perform engineering work. Paperclip provides the "company OS" (scheduling, budgets, audit trails, human oversight), gstack provides the "employee skills" (/review, /ship, /qa, /investigate, /autoplan, etc.).

**One sentence:** Paperclip gives the agent its job. gstack gives the agent its skills.

---

## Key Discovery: Architecture is Compatible

Paperclip's `claude_local` adapter already uses `--add-dir` to mount skills into Claude Code — the same mechanism gstack uses. Both systems speak the same language at the adapter level.

- `paperclip/packages/adapters/claude-local/src/server/execute.ts` line 440: `args.push("--add-dir", skillsDir)`
- gstack installs SKILL.md files under `.claude/skills/gstack/`
- Paperclip creates a temp dir with `.claude/skills/` symlinks per run, then passes `--add-dir`

Session continuity also aligns: Paperclip saves session IDs in `agentTaskSessions` table and passes `--resume <sessionId>` on subsequent wakes.

---

## Design Decision: One Agent, All Roles

gstack is designed for **one agent playing all roles** — all 32+ skills are installed in a single Claude Code instance. There's no concept of separate agents per skill. The org structure is implicit in skill chains (e.g., `/autoplan` chains CEO review -> design review -> eng review in one session).

This means the Paperclip model is: **one full-gstack agent per project**, not one agent per role. Paperclip manages multiple such agents across projects for parallelism.

---

## Two Friction Points

### Friction 1: AskUserQuestion in Non-Interactive Mode

**The problem:** gstack skills use `AskUserQuestion` for human checkpoints (blocking tool call). Paperclip runs Claude via `--print -` (non-interactive, piped stdin). `AskUserQuestion` will fail.

**gstack checkpoint inventory:**

| Skill | Checkpoints | Can Run Fully Autonomous? |
|-------|------------|--------------------------|
| `/ship` | 9 possible: version bump, ASK review items, Greptile comments, coverage gate, plan items, TODOS | Nearly — most runs hit zero checkpoints if diff is small and clean |
| `/review` | 3: ASK items (fix/skip), Greptile false positives | Yes, if all AUTO-FIX. ASK items need human judgment |
| `/qa` | 2: dirty working tree, WTF-likelihood safety valve (>20%) | Almost entirely — dirty tree is pre-answerable, WTF only triggers if things go badly |
| `/land-and-deploy` | 7: dry-run validation, inline review, pre-merge readiness gate (always asks), deploy failure, health check | No — pre-merge gate always requires approval |
| `/autoplan` | 2 mandatory: premise confirmation, final approval gate | No — both are intentionally non-automatable |

**Key pattern:** All skills use `AskUserQuestion` as the sole blocking mechanism. The word **STOP** in bold is the signal to halt. Skills have explicit "never stop for" and "always stop for" declarations.

**gstack checkpoint format (consistent across skills):**
```
I auto-fixed 5 issues. 2 need your input:

1. [CRITICAL] app/models/post.rb:42 — Race condition in status transition
   Fix: Add WHERE status = 'draft' to the UPDATE
   -> A) Fix  B) Skip

2. [INFO] app/services/generator.rb:88 — LLM output not type-checked
   Fix: Add JSON schema validation
   -> A) Fix  B) Skip

RECOMMENDATION: Fix both — #1 is a real race condition.
```

### Friction 2: Skill Chain Timeouts

Skills like `/autoplan` chain multiple review phases (CEO -> design -> eng -> DX). Each phase can take many turns. Paperclip has `maxTurnsPerRun` and `timeoutSec` limits. Long chains may exceed these.

Mitigation: Configure generous limits (maxTurnsPerRun: 200, timeoutSec: 1800). If exceeded, session saves and resumes on next heartbeat. gstack skills have idempotency checks (VERSION already bumped, PR already exists, etc.) for safe re-entry.

---

## Paperclip's Existing Approval System

Paperclip already has an approval workflow that can handle the AskUserQuestion problem:

1. Agent creates an approval via `POST /api/companies/{companyId}/approvals`
2. Agent's heartbeat run **completes** (exits). Session ID saved in `agentTaskSessions`
3. Approval appears in Paperclip web dashboard as "pending"
4. Human approves/rejects in the UI
5. Approval route **automatically wakes the requesting agent** with:
   - `PAPERCLIP_APPROVAL_ID`, `PAPERCLIP_APPROVAL_STATUS` env vars
   - `--resume <sessionId>` to restore the prior conversation
   - A wake prompt with approval context
6. Agent continues where it left off

**Current approval types:** `hire_agent`, `approve_ceo_strategy`, `budget_override_required`

**Current approval UI actions:** Approve, Reject, Request Revision, plus a comments section for free-text.

**Limitation for gstack:** The approval UI has no structured way to pick from lettered options (A/B/C). The human would need to write their choice in a comment, then click Approve. Works but clunky compared to gstack's interactive CLI experience.

---

## Solution Approaches Considered

### Approach 1: Bridge Skill (Recommended)

A new `SKILL.md` file mounted alongside gstack skills that teaches the agent:
- Detect Paperclip mode via `PAPERCLIP_*` env vars
- NEVER call `AskUserQuestion` (it won't work in `--print` mode)
- For mechanical decisions (skill says "never stop for"): auto-decide using defaults
- For judgment decisions (skill says "always stop for"): create Paperclip approval, post options as issue comment, set issue to blocked, exit run
- On resume (PAPERCLIP_APPROVAL_ID set): fetch approval response, continue skill

**Pros:** No gstack template modifications. No Paperclip adapter code changes. Pure prompt engineering. Zero coupling between the two codebases.

**Cons:** Relies on Claude following instructions correctly. No guarantee it won't try to call AskUserQuestion anyway.

### Approach 2: Modify gstack Templates

Add Paperclip-aware conditionals to each SKILL.md.tmpl:
```
If PAPERCLIP_AGENT_ID is set:
  → Create Paperclip approval instead of AskUserQuestion
Else:
  → AskUserQuestion as normal
```

**Pros:** Precise per-checkpoint control. Each skill knows exactly how to handle Paperclip mode.

**Cons:** 32+ files to modify. Every gstack update risks breaking the integration. Tight coupling.

### Approach 3: Adapter-Level Interception

Modify Paperclip's `claude_local` adapter to intercept `AskUserQuestion` tool calls in Claude's streaming JSON output, automatically convert them to approvals, and end the run.

**Pros:** Fully transparent — gstack skills don't need to know about Paperclip at all.

**Cons:** Complex engineering. Requires parsing Claude's streaming output for specific tool call patterns. Edge cases around partial tool calls, retries, etc.

### Approach 4: Pre-Answer Everything (Fully Autonomous)

Configure the prompt to pre-answer all checkpoint questions: "always MICRO bump, always fix recommended, always stash dirty trees, always merge if tests pass."

**Pros:** Fully autonomous, zero human interaction.

**Cons:** Loses safety gates gstack intentionally built. Risky for production code.

### Approach 5: Hybrid (Bridge Skill + Pre-Answers)

Bridge skill provides defaults for mechanical decisions AND creates approvals for judgment calls. This is the recommended approach.

---

## Approval UI Gap

The current Paperclip approval detail page (`ui/src/pages/ApprovalDetail.tsx`) renders type-specific payloads via `ApprovalPayloadRenderer` in `ui/src/components/ApprovalPayload.tsx`:

- `HireAgentPayload` — shows name, role, title, adapter, skills
- `CeoStrategyPayload` — shows plan/strategy text
- `BudgetOverridePayload` — shows scope, limit, observed amount

For gstack checkpoints, there's no custom renderer. The payload would fall through to `CeoStrategyPayload` (the default), which just dumps the payload as JSON or text.

**Optional improvement:** Add a `GstackCheckpointPayload` renderer (~50 lines) that shows:
- Skill name and step
- The question
- Options as clickable buttons that set `decisionNote` on approve
- The agent's recommendation highlighted

This is a nice-to-have, not a blocker. The comment + approve flow works without it.

---

## Implementation Scope Options

### Option A: Bridge Skill Only (Minimal)

- Create `paperclip/skills/gstack-bridge/SKILL.md` (~200 lines)
- Create `paperclip/skills/gstack-bridge/references/skill-checkpoint-map.md`
- Add `gstack_checkpoint` to approval types in `packages/shared/src/constants.ts`
- Import gstack skills manually via existing Paperclip API
- Configure agent with generous timeouts

### Option B: Bridge Skill + Checkpoint UI

Everything in Option A, plus:
- Add `GstackCheckpointPayload` component to `ui/src/components/ApprovalPayload.tsx`
- Register `gstack_checkpoint` type icon and label

### Option C: Bridge Skill + UI + Import Script

Everything in Option B, plus:
- Build a script that scans gstack directory and bulk-imports all skills as Paperclip company skills

---

## Open Questions

1. Which scope to start with (A, B, or C)?
2. Should we test with a specific gstack skill first? `/review` is simplest (3 checkpoints). `/ship` is the best stress test (9 checkpoints).
3. Do we need a way for the human to pre-configure default answers per skill (e.g., "for /ship, always MICRO bump") in the Paperclip UI, or is hardcoding defaults in the bridge skill sufficient?
4. How should the bridge skill handle `/autoplan`'s mandatory premise gate? This isn't a simple approve/reject — it requires the human to confirm factual premises about their project.

---

## Key Files Reference

| File | Role |
|------|------|
| `paperclip/packages/adapters/claude-local/src/server/execute.ts` | Claude adapter — skill mounting, session resume, prompt construction |
| `paperclip/packages/adapters/claude-local/src/server/skills.ts` | Skill listing, ephemeral skill dir creation |
| `paperclip/packages/adapter-utils/src/server-utils.ts` | `renderPaperclipWakePrompt`, template rendering |
| `paperclip/server/src/services/heartbeat.ts` | Run queue, wake, execute, session management |
| `paperclip/server/src/services/approvals.ts` | Approval CRUD and side effects |
| `paperclip/server/src/routes/approvals.ts` | Approval resolution triggers agent wake |
| `paperclip/ui/src/pages/ApprovalDetail.tsx` | Approval detail page (Approve/Reject/Revision buttons) |
| `paperclip/ui/src/components/ApprovalPayload.tsx` | Type-specific approval renderers |
| `paperclip/packages/shared/src/constants.ts` | Approval types, issue statuses, agent statuses |
| `paperclip/skills/paperclip/SKILL.md` | Core Paperclip skill — heartbeat procedure, approval API patterns |
| `gstack/hosts/claude.ts` | Claude host config — skill installation paths |
| `gstack/hosts/index.ts` | Host registry — all 8 supported agents |
| `gstack/ship/SKILL.md.tmpl` | Ship skill — 9 checkpoints, most complex |
| `gstack/review/SKILL.md.tmpl` | Review skill — 3 checkpoints, simplest |
| `gstack/qa/SKILL.md.tmpl` | QA skill — 2 checkpoints, mostly autonomous |
| `gstack/land-and-deploy/SKILL.md.tmpl` | Deploy skill — 7 checkpoints, always asks pre-merge |
| `gstack/autoplan/SKILL.md.tmpl` | Autoplan — 2 mandatory non-automatable checkpoints |
