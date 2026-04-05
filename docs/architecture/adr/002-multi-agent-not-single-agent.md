# ADR 002: Multi-Agent Company (One Agent Per Role) Over Single-Agent (All Skills in One Instance)

**Status:** Accepted
**Date:** 2026-04-04
**Deciders:** Engineering Company template authors

---

## Context

gstack was originally designed for interactive use by a single human with a single Claude Code instance. The `SKILL.md` root file acts as a routing layer: it reads the user's request and invokes the appropriate skill (`/review`, `/qa`, `/ship`, etc.) within the same session. One agent, all 32+ skills, one session.

When building the Engineering Company template on top of Paperclip, we needed to decide how to structure the agents:

**Option A (single-agent):** One agent with all 32+ gstack skills. The agent reads all skills and applies them based on the task type.

**Option B (multi-agent):** One agent per role, each with 2-5 role-appropriate skills. Tasks are routed to the right agent by type.

---

## Alternatives Considered

### Alternative A: Single-Agent (All Skills, One Instance)

One "engineering agent" is created with all gstack skills assigned: `/autoplan`, `/review`, `/ship`, `/qa`, `/qa-only`, `/cso`, `/investigate`, `/codex`, `/land-and-deploy`, `/canary`, `/benchmark`, `/retro`, `/devex-review`, `/document-release`, `/design-*`, `/plan-*-review`, etc.

The agent reads all incoming tasks and routes to the appropriate skill within a single run.

**Pros:**
- Simpler setup — one agent, no org chart
- No delegation latency — all work happens in one heartbeat cycle
- Consistent context — the agent has seen all prior task history
- Closer to gstack's original design intent

**Cons:**
- Context window pressure — 32 skill files loaded simultaneously is significant context overhead
- No parallel work — the single agent works serially; while it is reviewing code, it cannot simultaneously run QA
- Role confusion — an agent responsible for both security audits and feature implementation is likely to do neither as well as a specialist
- Heartbeat scheduling complexity — how often should one agent run? Optimizing for CEO-speed (15 min) is expensive; optimizing for SecurityOfficer-speed (6 hours) makes it too slow for other tasks
- Poor isolation — a runaway QA loop could exhaust the budget for the entire team
- Hard to reason about — when the single agent makes a decision, which "role" made it?

### Alternative B: Multi-Agent (One Agent Per Role, 2-5 Skills Each) — Selected

Nine agents, each scoped to a specific engineering role, with only the skills relevant to that role. The org chart (CEO → CTO → ICs) mirrors a real engineering team structure. Tasks flow down through delegation and decisions flow up through escalation.

**Pros:**
- **Natural org structure** — maps to how engineering teams actually work; easy for humans to understand what each agent does and why
- **Focused context windows** — each agent loads only 3-6 skill files, leaving most of the context window for actual task work
- **Parallel work** — CTO can review code while QAEngineer runs tests while SecurityOfficer audits the auth module — simultaneously
- **Independent budget control** — each agent has its own budget; a runaway SeniorEngineer loop does not affect the SecurityOfficer's budget
- **Role clarity** — every decision has a clear owner (the CTO approved the review, the ReleaseEngineer approved the deploy)
- **Independent heartbeat tuning** — CEO can run every 15 minutes (fast triage) while SecurityOfficer runs every 6 hours (scheduled audits)
- **Paperclip's native model** — Paperclip was designed for multi-agent companies with org charts; using it with a single agent misses most of its value

**Cons:**
- **Delegation latency** — a task requiring CEO → CTO → SeniorEngineer has 15 + 20 + 30 = 65 minutes of heartbeat delay before the first line of code is written
- **More setup complexity** — 9 agents, 9 onboarding bundles, skill assignments for each
- **Cross-agent communication is async** — no direct agent-to-agent calls; all communication is through Paperclip issues and comments

---

## Decision

Use multi-agent (Alternative B).

The parallel work capability and role clarity arguments are decisive. An engineering team where the same person writes code, reviews it, deploys it, and audits it for security is not an engineering team — it is one person wearing many hats. That is gstack's interactive mode, and it works well for a single human. But a multi-agent company should mirror how teams actually work.

The delegation latency is a real cost, but it is the correct cost. Asynchronous delegation is not a limitation to work around — it is the right model for work that genuinely involves different roles. A security audit takes time because security engineers are not coding engineers.

---

## Rationale

**Paperclip's value is in the org chart.** Paperclip provides org charts, issue delegation, approval governance, and budget isolation per agent. Using a single agent ignores all of this and turns Paperclip into a simple cron runner. The multi-agent structure is what makes the Paperclip + gstack combination more than the sum of its parts.

**Context window management is real.** A single agent with 32 skill files loaded has significantly less working memory available for actual task content — code diffs, file contents, test output. Each skill file is 200-1500 lines. A focused agent with 3-4 skill files is materially more effective at its specific work.

**Role specialization produces better outputs.** The CTO running only `/review` and `/ship` is a code reviewer and release manager. It reads about code review and release on every heartbeat — it is deeply familiar with that workflow. An agent that also does security audits, design reviews, and DX benchmarks is a generalist that does everything less well.

**Heartbeat tuning matters.** The SecurityOfficer running every 6 hours is by design — security sweeps are expensive and should not happen every 30 minutes. If the SecurityOfficer were merged into a single agent, you would need to tune the single agent's heartbeat for all use cases simultaneously, which is impossible to optimize.

---

## Trade-offs

| Concern | Impact | Mitigation |
|---------|--------|-----------|
| Delegation latency | Multi-step tasks take hours | Calibrated heartbeat schedules minimize delay; for urgent work, tasks can be assigned directly to the specialist rather than through CEO |
| More setup complexity | 9 agents, 9 onboarding bundles | `setup.sh` automates the provisioning; `company.json` documents the configuration |
| Cross-agent context loss | Agent B does not have Agent A's conversational history | Task descriptions and comments carry context; delegation tasks include full context from parent |
| Async coordination failure | If agent B's task fails silently, agent A waits forever | Issue status updates and comments make failures visible; `in_review` with no child progress is an observable signal |

---

## Consequences

- The Engineering Company template defines 9 agents with distinct roles, heartbeat schedules, and skill sets
- Task routing is the CEO's job — the CEO reads incoming tasks and creates the right subtask for the right specialist
- The bridge skill's delegation protocol (Step 6) handles the cross-role phase delegation that gstack skill chains require
- All agent-to-agent communication flows through Paperclip issues and comments, not through direct API calls
- Total wall-clock time for complex multi-agent tasks is bounded by the sum of heartbeat schedule maxima; this is a known and accepted cost
- Adding a new specialist agent (e.g., a dedicated DBA agent) is a standard operation — create onboarding docs, import skills, register the agent, assign it to the relevant manager in the org chart
