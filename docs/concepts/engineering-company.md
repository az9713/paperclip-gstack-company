# The Engineering Company

The Engineering Company template (`companies/engineering/`) defines a 9-agent autonomous engineering team. This document covers each agent's role and skills, the heartbeat schedules and their rationale, and complete task flow examples for common scenarios.

---

## The Full Org Chart

```
Human (Board Operator)
└── CEO (claude-opus-4-6, every 15 min)
    ├── CTO (claude-sonnet-4-6, every 20 min)
    │   ├── SeniorEngineer (claude-sonnet-4-6, every 30 min)
    │   ├── ReleaseEngineer (claude-sonnet-4-6, every 30 min)
    │   └── DevExEngineer (claude-sonnet-4-6, hourly)
    ├── QALead (claude-sonnet-4-6, every 4 hours)
    │   └── QAEngineer (claude-sonnet-4-6, every 30 min)
    ├── SecurityOfficer (claude-sonnet-4-6, every 6 hours)
    └── DesignLead (claude-sonnet-4-6, every 30 min)
```

The CEO uses `claude-opus-4-6` (the most capable model) because it makes the highest-stakes decisions: what to build, who to assign it to, and when to escalate to the human. All other agents use `claude-sonnet-4-6`, which balances capability and cost for implementation-focused work.

---

## Agent Profiles

### CEO

**Skills:** `/autoplan`, `/plan-ceo-review`, `/office-hours`
**Heartbeat:** every 15 minutes
**Model:** claude-opus-4-6 (80 max turns, 15 min timeout)

The CEO is the entry point for all tasks. It does not write code or run engineering commands. Its job is to triage incoming work, identify which specialists should handle each part, create subtasks, and monitor progress.

When a task requires strategic planning (e.g., "Build a new user onboarding flow"), the CEO runs `/autoplan` to generate a plan document that chains CEO → design → engineering → DX review phases. In Paperclip mode, the design, engineering, and DX review phases are delegated as subtasks to DesignLead, CTO, and DevExEngineer respectively.

For plan review tasks (e.g., a human sends a spec doc for review), the CEO runs `/plan-ceo-review` — a CEO-level strategic review that checks ambition, scope, user value, and completeness.

The CEO uses Opus because it needs to make nuanced routing decisions. A misrouted task costs hours of agent time on heartbeat delays.

### CTO

**Skills:** `/plan-eng-review`, `/review`, `/ship`
**Heartbeat:** every 20 minutes
**Model:** claude-sonnet-4-6 (150 max turns, 30 min timeout)

The CTO owns engineering execution: code review, release management, and coordination of the engineering ICs. It never writes code directly — it reviews, ships, and delegates.

Typical CTO flow for a feature task:
1. Receives delegation from CEO
2. Runs `/plan-eng-review` if a plan document was provided
3. Creates implementation subtask for SeniorEngineer
4. When SeniorEngineer marks work as `in_review`, runs `/review` on their branch
5. Runs `/ship` to bump version, write CHANGELOG, and create the PR
6. Creates deploy subtask for ReleaseEngineer

The CTO's `maxTurnsPerRun: 150` reflects that review + ship workflows can be involved, but are bounded — the CTO does not run open-ended implementation loops.

### SeniorEngineer

**Skills:** `/investigate`, `/codex`
**Heartbeat:** every 30 minutes
**Model:** claude-sonnet-4-6 (200 max turns, 30 min timeout)

The SeniorEngineer handles feature implementation and bug fixing. It has the highest `maxTurnsPerRun` (200) because implementation work can require many read-write-test cycles.

`/investigate` is used for root-cause debugging: when a task is "why is the login button broken on mobile", the SeniorEngineer runs `/investigate` to trace the problem systematically before writing any code.

`/codex` provides a second AI opinion by running the same question through OpenAI Codex CLI. This is useful for architecture decisions where a single model might have blind spots.

After implementation, SeniorEngineer marks its task `in_review` and posts a comment with the branch name, test results, and a summary of changes for the CTO to review.

### ReleaseEngineer

**Skills:** `/land-and-deploy`, `/canary`, `/document-release`, `/setup-deploy`
**Heartbeat:** every 30 minutes
**Model:** claude-sonnet-4-6 (200 max turns, 30 min timeout)

The ReleaseEngineer handles all deployment operations. It never writes application code — it merges PRs, deploys them, monitors canary deployments, and updates release documentation.

`/land-and-deploy` runs the full deploy pipeline: check CI status, run pre-merge validations, create a pre-merge readiness approval (always — this is a hard gate), merge after approval, trigger deploy, run post-deploy health checks.

`/canary` monitors production health after a deploy. It checks error rates, latency percentiles, and key business metrics for a configured window (typically 15-30 minutes).

`/setup-deploy` is a one-time setup skill that configures the deploy pipeline for a new project — what deploy command to run, what environment variables are needed, what health check URL to monitor.

`/document-release` generates release notes from CHANGELOG, PR descriptions, and commit history, and publishes them to the designated release documentation location.

### DevExEngineer

**Skills:** `/devex-review`, `/plan-devex-review`, `/retro`, `/benchmark`
**Heartbeat:** hourly
**Model:** claude-sonnet-4-6 (150 max turns, 20 min timeout)

The DevExEngineer focuses on developer experience quality: how easy is it for developers to work in this codebase? It runs less frequently (hourly) because its work is scheduled rather than reactive.

`/devex-review` audits the developer experience: build speed, test feedback loops, error message quality, documentation coverage, CI/CD reliability.

`/retro` runs weekly retrospectives based on git history, issue comments, and previous retro notes. It identifies patterns: what shipped smoothly, what caused repeated problems, what process improvements would help.

`/benchmark` detects performance regressions by comparing before/after benchmarks on critical code paths.

### QALead

**Skills:** `/qa-only`
**Heartbeat:** every 4 hours
**Model:** claude-sonnet-4-6 (150 max turns, 20 min timeout)

The QALead runs `report-only` quality assurance. It finds and documents bugs without fixing them. Its output is a structured bug report which becomes the basis for QAEngineer subtasks.

`/qa-only` is fully autonomous — no checkpoints. It browses the application, exercises user flows, checks edge cases, and produces a categorized report with bug severity and reproduction steps. The QALead then creates subtasks for QAEngineer for each bug found.

The 4-hour heartbeat reflects that QA sweeps are relatively infrequent — the team does not want QA running every 30 minutes on every small change.

### QAEngineer

**Skills:** `/qa`
**Heartbeat:** every 30 minutes
**Model:** claude-sonnet-4-6 (200 max turns, 30 min timeout)

The QAEngineer handles the full QA loop: find bugs, write regression tests, fix them, verify. The `/qa` skill is atomic — each bug gets its own commit. The QAEngineer checks out a task (one bug), fixes it, verifies the fix, commits, and moves to the next.

`/qa` uses the headless browser (`$B` commands) to exercise the UI flows and capture screenshots as bug evidence.

The bridge skill creates one approval checkpoint in `/qa`: if the "WTF-likelihood score" exceeds 20% (too many reverts, fixes touching unrelated files, compounding complexity), the skill pauses and asks: should we continue, or stop and reassess?

### SecurityOfficer

**Skills:** `/cso`, `/careful`, `/guard`
**Heartbeat:** every 6 hours
**Model:** claude-sonnet-4-6 (150 max turns, 20 min timeout)

The SecurityOfficer runs security audits and can activate enhanced safety modes. It runs every 6 hours because security sweeps are scheduled, not reactive.

`/cso` runs an OWASP Top 10 + STRIDE threat modeling audit on the codebase. It produces a structured report with findings categorized by severity and posts results as issue comments.

`/careful` activates careful mode: the agent adds an extra review step before any code change, surfacing potential side effects before they are applied.

`/guard` restricts edits to a specified directory, preventing accidental changes outside the defined scope.

### DesignLead

**Skills:** `/design-review`, `/design-html`, `/design-consultation`, `/design-shotgun`, `/plan-design-review`
**Heartbeat:** every 30 minutes
**Model:** claude-sonnet-4-6 (150 max turns, 20 min timeout)

The DesignLead handles all UI/UX work. It reviews designs, converts mockups to HTML, creates design systems, and explores visual directions.

`/design-review` audits the current UI for consistency, accessibility, and visual quality — similar to `/review` but for design rather than code.

`/design-html` converts a design mockup or description into a working HTML/CSS prototype.

`/design-consultation` creates a design system from scratch when starting a new product: typography, color palette, component library, spacing scale.

`/design-shotgun` generates multiple visual directions quickly — useful for early-stage exploration where you want to see several options before committing.

`/plan-design-review` reviews a plan document from the design perspective: does the spec account for the user experience, does the UI handle edge cases, are the visual requirements clear?

---

## Typical Task Flows

### New Feature

```
Human creates task → assigns to CEO
CEO wakes → identifies as engineering work → delegates to CTO
CTO wakes → runs /plan-eng-review if plan exists → delegates implementation to SeniorEngineer
SeniorEngineer wakes → runs /investigate (if codebase unfamiliar) → implements → marks in_review
CTO wakes → runs /review → may create approval for ASK items → human approves → runs /ship
ReleaseEngineer wakes → runs /land-and-deploy → always creates pre-merge approval → human approves → deploys
QALead wakes (4h) → runs /qa-only → finds bugs → creates subtasks for QAEngineer
QAEngineer wakes → runs /qa → fixes bugs → commits → done
```

Total elapsed time (typical): 3-8 hours depending on heartbeat timing and approval delays.

### Bug Report

```
Human creates task "Bug: login fails on mobile Safari" → assigns to CEO
CEO wakes → recognizes as engineering bug → delegates to CTO with note: "debug and fix"
CTO wakes → delegates to SeniorEngineer: "investigate and fix login mobile Safari bug"
SeniorEngineer wakes → runs /investigate → finds root cause → fixes → marks in_review
CTO wakes → runs /review on fix → AUTO-FIX only (simple fix) → runs /ship
ReleaseEngineer wakes → deploys the fix → runs /canary → all clear
```

Total elapsed time: 2-5 hours.

### Security Audit

```
Human creates task "Run security audit on auth module" → assigns to SecurityOfficer directly (or via CEO)
SecurityOfficer wakes (6h schedule) → runs /cso on the auth module → generates OWASP + STRIDE report
SecurityOfficer posts findings as comments → creates subtasks for high-severity items → assigns to SeniorEngineer
SeniorEngineer wakes → implements security fixes → marks in_review
CTO wakes → reviews security fixes → ships
```

Total elapsed time: 6-24 hours (SecurityOfficer's 6h heartbeat dominates).

### Design Review

```
Human creates task "Design review: new onboarding flow" → assigns to DesignLead
DesignLead wakes → runs /design-review → audits the existing UI → posts findings
DesignLead runs /design-html to prototype improvements
DesignLead creates subtask for SeniorEngineer: "Implement design improvements from ENG-22"
```

### Full Planning Cycle (/autoplan)

```
Human creates task "Plan a complete redesign of the dashboard" → assigns to CEO
CEO wakes → recognizes as planning task → runs /autoplan
/autoplan Phase 1 (CEO review): CEO reviews the premise → creates approval for premise confirmation
Human approves premise
CEO resumes → creates subtask for DesignLead: /plan-design-review
CEO creates subtask for CTO: /plan-eng-review
CEO creates subtask for DevExEngineer: /plan-devex-review
CEO sets own task to in_review, waits

DesignLead wakes → runs /plan-design-review → posts design findings
CTO wakes → runs /plan-eng-review → posts engineering findings
DevExEngineer wakes → runs /plan-devex-review → posts DX findings

CEO wakes (all subtasks done) → consolidates findings → creates final approval gate
Human approves → CEO posts final plan document → marks task done
```

---

## Why Each Heartbeat Schedule

The heartbeat schedules were designed around two factors: work urgency and token cost.

High-frequency schedules (15-20 min) are for agents whose delays cascade. If the CEO delays 30 minutes, every downstream agent is also delayed 30 minutes. The CEO runs every 15 minutes to minimize this cascade effect.

Medium-frequency schedules (30 min) balance responsiveness with cost for implementation agents (SeniorEngineer, QAEngineer, DesignLead). These agents do bounded work per wake — implement a feature, fix a bug, run a review — so a 30-minute gap is acceptable.

Low-frequency schedules (1h, 4h, 6h) are for agents whose work is batch-oriented and not time-sensitive. The DevExEngineer runs retros and benchmarks that are typically done once per sprint or per week. The SecurityOfficer runs scheduled audits. The QALead does quality sweeps that complement, rather than gate, the main development flow.

If your workflow needs faster response times, you can adjust heartbeat schedules in `company.json` and re-run `setup.sh`. The trade-off is token cost: a 5-minute heartbeat for 9 agents running 24/7 costs significantly more than 30-minute heartbeats.
