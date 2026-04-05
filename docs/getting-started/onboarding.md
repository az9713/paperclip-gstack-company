# Onboarding: Understanding AI Agent Companies

A conceptual guide for readers new to AI agents, gstack skills, and multi-agent orchestration. No commands required — just reading.

---

## What Is an AI Agent?

An AI agent is a language model that can take actions, not just answer questions. Instead of asking Claude "how do I write a health check endpoint?" and copying the answer, an AI agent reads your codebase, writes the code, runs the tests, and creates the pull request — all without you typing a single line.

The key insight is that language models can use tools. They can read files, write files, run shell commands, and call APIs. Chain together enough tool calls and the model is doing real engineering work, not just describing how to do it.

An individual agent is not magic — it still needs clear instructions about what to do, what tools it can use, and when to stop and ask a human. That is what gstack skills provide.

---

## What Is a Skill?

A skill is a structured set of instructions for an agent. Think of it like a job description card that an employee reads before starting a task — but extremely detailed and precise, because the "employee" has no common sense unless you write it down.

A gstack skill is a Markdown file called SKILL.md. It tells the agent:
- What the workflow is (step by step)
- What tools to use at each step
- What to check for quality
- Which decisions to make automatically
- Which decisions to pause and ask a human about

For example, the `/review` skill (the code review skill) teaches an agent to:
1. Find the diff between the current branch and main
2. Check for performance problems (N+1 queries, missing indexes)
3. Check for security issues
4. Check for type errors and stale code
5. Categorize each finding as AUTO-FIX (apply without asking) or ASK (need human input)
6. Apply all AUTO-FIX items
7. Present all ASK items to the human with options

Without the skill, you would get a vague "looks good to me" from the agent. With the skill, you get a structured review with specific findings categorized by severity.

---

## What Is a Multi-Agent Company?

A single agent with many skills is like a single person who knows how to do everything — software engineer, QA tester, security auditor, designer, release engineer. That person exists, but they are rare, expensive, and can only do one thing at a time.

A multi-agent company is more like an actual company: specialists who know their domain deeply, working in parallel, with coordination happening through a management structure.

In this repository, there is a 9-agent engineering team:

- **CEO** — strategic planning and delegation. Reads incoming tasks, decides who should handle them, creates subtasks, and escalates to the human when needed.
- **CTO** — engineering management. Reviews code, ships releases, coordinates the engineering team.
- **SeniorEngineer** — implementation. Investigates problems, writes code, fixes bugs.
- **ReleaseEngineer** — shipping. Merges PRs, deploys to production, monitors canary deployments.
- **DevExEngineer** — developer experience. Runs retrospectives, benchmarks, and DX audits.
- **QALead** — quality oversight. Runs report-only QA, finds bugs, creates fix tasks.
- **QAEngineer** — QA execution. Finds bugs, writes tests, applies fixes atomically.
- **SecurityOfficer** — security audits. Runs OWASP Top 10 and STRIDE threat modeling.
- **DesignLead** — design work. Reviews UI/UX, converts designs to HTML, runs design consultations.

The difference from a single agent: these agents run in parallel, each focused on their specialty. The CTO can be reviewing code while the QAEngineer is testing and the SecurityOfficer is auditing — simultaneously.

---

## How Does Work Flow?

The coordination model is similar to a real company with an org chart. Work flows down through delegation, and decisions flow up through escalation.

### Delegation (work flowing down)

When you create a task and assign it to the CEO, the CEO does not do the work itself. The CEO reads the task, decides which specialists should handle each part, and creates subtasks:

- "Build user auth with OAuth2" → CEO creates subtask for CTO: "Implement OAuth2 auth"
- CTO creates subtask for SeniorEngineer: "Write OAuth2 implementation"
- SeniorEngineer does the work, then CTO reviews it

Each agent works on what they are responsible for and hands off the rest.

### Escalation (decisions flowing up)

When an agent hits a decision point that requires human judgment, it does not guess. It creates an approval request — essentially a structured question — and pauses work until the human responds:

- "The pre-merge readiness gate shows 3 failing tests. Should I proceed anyway or block the deploy?"
- "The `/review` skill found a potential SQL injection in the auth middleware. Fix it now or file a separate security PR?"

The human sees these in the Paperclip web UI under Approvals. They pick an option, and the agent resumes where it left off.

---

## The Scheduling Model

Agents do not run continuously. Each agent wakes on a schedule (like a cron job), checks what needs doing, does it, and goes back to sleep. This is called a **heartbeat**.

- The CEO wakes every 15 minutes and checks for new tasks to delegate.
- The CTO wakes every 20 minutes and checks for delegated work from the CEO.
- Engineers wake every 30 minutes.
- The SecurityOfficer wakes every 6 hours (security audits are less time-sensitive).

This means there is latency in the system. When you create a task, the CEO might not see it for up to 15 minutes. When the CEO delegates to the CTO, the CTO might not see that for up to 20 minutes. For a multi-step task like "Build user auth", the total wall-clock time from creation to completion might be several hours.

This is a trade-off. The benefit is that agents are not burning compute and API tokens constantly — they only run when there is work to do, and they sleep efficiently between heartbeats.

---

## What Is Paperclip?

Paperclip is the orchestration layer — the "company operating system" that runs the agents. It handles:

- **Org chart**: who reports to whom, what each agent's role and title is
- **Task management**: creating issues, tracking their status, threading comments
- **Heartbeats**: waking agents on schedule and giving them the context they need
- **Approvals**: presenting human decision points and routing the response back to the right agent
- **Budget**: tracking how much each agent spends in API tokens and enforcing monthly limits
- **Session continuity**: resuming the same Claude Code session across heartbeats so agents do not lose context

Without Paperclip, you would need to manually run Claude Code for each agent, track what each one is doing in a spreadsheet, copy context between sessions, and watch for decisions that need human input.

---

## What Is gstack?

gstack is the skill layer — the "employee training manual" that teaches each agent how to do their job. Without gstack, agents know they should "do a code review" but they do not have a systematic workflow for it. With gstack, the `/review` skill gives the CTO a 15-step checklist, a categorized output format, and clear rules for which findings need human input.

gstack skills are opinionated. They encode the builder philosophy of Garry Tan — "Boil the Lake" (always do the complete thing, not the shortcut), "Search Before Building" (check what exists before designing from scratch), and "User Sovereignty" (agents recommend, humans decide). These principles are injected into every skill's preamble automatically.

---

## How gstack and Paperclip Connect

gstack was designed for interactive use: one human + one Claude Code session + one agent with all the skills. You type `/review`, Claude reviews the code, asks you questions, waits for your answers, and continues.

Paperclip is the opposite: many agents, each running headlessly (no human at the terminal), on a schedule.

The tension: gstack skills expect a human to answer questions. Paperclip runs agents without one.

The solution is the **gstack-bridge skill**. It is a custom skill that every agent in the Engineering Company loads first, before running any gstack skill. It teaches agents the three-tier decision model:

1. **Mechanical decisions** (which version number to use, whether to stash uncommitted changes) → decide automatically using sensible defaults
2. **Judgment decisions** (should this ASK finding be fixed or deferred?, should this pre-merge proceed or block?) → create a Paperclip approval and wait for a human
3. **Pre-answered decisions** (if the task description already says "use MINOR bump" or "skip Greptile false positives") → use that answer directly

The bridge skill also handles cross-role phases. The `/autoplan` skill normally runs a CEO review, then a design review, then an engineering review, all in one session. In Paperclip, the CEO cannot do the design review — that is the DesignLead's job. So the bridge skill teaches the CEO to create a subtask for DesignLead instead of doing the design review inline.

---

## A Full Example: "Build Auth Feature"

Here is the end-to-end flow for a realistic task, showing each handoff:

**You create:** "Build user authentication with email/password and OAuth2 (Google). Write backend routes, database migrations, frontend login page, tests, and PR."

**CEO wakes (within 15 min):**
- Reads the task
- Recognizes it as cross-functional: needs engineering (backend + frontend), QA, security, and design
- Creates subtasks:
  - → CTO: "Implement auth feature (backend, frontend, migrations, tests)"
  - → SecurityOfficer: "Security audit of auth implementation when ready"
  - → DesignLead: "Design review of login page UI"
- Posts comment: "Delegated to CTO, SecurityOfficer, DesignLead. CTO is the blocker."

**CTO wakes (within 20 min):**
- Reads its subtask
- Decides the implementation is complex enough to run `/autoplan` for engineering planning
- Runs `/plan-eng-review` — reviews the architecture plan, comments findings
- Delegates actual implementation to SeniorEngineer: "Implement auth routes, OAuth2 integration, database migrations"
- Posts comment: "Delegated implementation to SeniorEngineer (ENG-5). Will review when complete."

**SeniorEngineer wakes (within 30 min):**
- Reads the implementation task
- Runs `/investigate` to understand the codebase: existing auth patterns, database schema, test setup
- Runs `/codex` to get a second-opinion from another AI on the auth design
- Implements all the code: database migrations, backend routes, OAuth2 integration, frontend component, tests
- Marks its task `in_review` and posts: "Implementation complete. Branch: feature/auth-oauth2. All tests passing."

**CTO wakes (next heartbeat):**
- Sees SeniorEngineer's task is in_review
- Runs `/review` on the branch
- Finds an ASK item: "The OAuth2 state parameter is not being validated — potential CSRF vector. Fix inline or file separate security PR?"
- Creates a Paperclip approval with the question and two options
- Sets task to `blocked`, exits

**You (human) see the approval in the Paperclip UI:**
- Read: "OAuth2 state parameter not validated — potential CSRF. Option A: Fix inline now. Option B: File separate security PR."
- You approve Option A: "Fix inline — this is critical path for auth"

**CTO resumes (woken by Paperclip after your approval):**
- Reads the approval decision: fix inline
- Continues running `/review` — marks the CSRF issue as AUTO-FIX with the chosen approach
- Review passes. Runs `/ship` to bump version and create the PR
- Creates a deploy subtask for ReleaseEngineer

**ReleaseEngineer wakes:**
- Runs `/land-and-deploy`
- Reaches the pre-merge readiness gate — always creates an approval: "Tests pass, 2 reviewers. Ready to merge and deploy?"
- Sets task to `blocked`

**You approve the merge:**
- ReleaseEngineer resumes, merges the PR, deploys
- Runs `/canary` to monitor production health post-deploy

**SecurityOfficer wakes (next 6-hour heartbeat):**
- Runs `/cso` security audit on the new auth code
- Finds a medium severity issue in token storage. Posts to the parent task as a comment: "OAuth2 token stored in localStorage — should use httpOnly cookie. Created ENG-12 for fix."

**QALead wakes (next 4-hour heartbeat):**
- Runs `/qa-only` on the auth feature
- Finds a bug: "Login with invalid email shows blank screen instead of error message"
- Creates subtask for QAEngineer: "Fix login validation error display"

**QAEngineer wakes:**
- Runs `/qa`: finds the bug, writes a regression test, fixes the validation, verifies the fix, commits atomically

**The task is done.** Total wall-clock time: likely 6-12 hours depending on heartbeat timing and how many approval cycles are needed. Human time: ~5 minutes across two approval decisions.

---

## Where to Go Next

Now that you understand the conceptual model:

- [Quickstart](quickstart.md) — get the system running with real commands
- [Key Concepts](../overview/key-concepts.md) — precise definitions of every term
- [Engineering Company](../concepts/engineering-company.md) — detailed breakdown of each agent's role
- [Bridge Skill](../concepts/bridge-skill.md) — deep dive into how the headless/interactive bridge works
