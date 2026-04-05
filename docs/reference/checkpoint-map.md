# Checkpoint Map

Per-skill inventory of every checkpoint in gstack. For each checkpoint: when it triggers, the default auto-decide behavior in Paperclip mode, and whether it creates a Paperclip approval.

Source: `companies/engineering/skills/gstack-bridge/references/checkpoint-map.md`

---

## Reading This Table

**"Auto-decide" checkpoints** are Tier 1 (mechanical) — the agent decides using the listed default without creating an approval.

**"Yes — approval" checkpoints** are Tier 2 (judgment) — the agent creates a `gstack_checkpoint` approval, sets the issue to `blocked`, and waits for a human response.

**"No"** means the skill handles the situation autonomously without pausing.

---

## `/review`

| Checkpoint | When It Triggers | Default (Paperclip) | Escalate? |
|------------|-----------------|---------------------|-----------|
| ASK items — fix vs. skip | Review finds issues requiring judgment (security, behavior changes, API contract changes) | — | **Yes** — one approval listing all ASK items with options |
| AUTO-FIX items | Review finds mechanically fixable issues (dead code, N+1 queries, type errors, stale comments) | Always apply all automatically | No |
| Greptile VALID & ACTIONABLE | Greptile finds a real, confirmed issue | Fix it automatically | No |
| Greptile FALSE POSITIVE | Greptile comment appears to be wrong | — | **Yes** — approval asking human to confirm |
| No ASK items | All findings were AUTO-FIX | Skip — no checkpoint | No |

**Note:** ASK items are batched into a single approval, not one approval per item. The options list all items with "fix / defer" choices for each.

---

## `/ship`

| Checkpoint | When It Triggers | Default (Paperclip) | Escalate? |
|------------|-----------------|---------------------|-----------|
| Uncommitted changes | Dirty working tree | Include them automatically | No |
| TODOS.md missing | No TODOS.md found | Create it automatically | No |
| TODOS.md disorganized | TODOS.md structure is poor | Leave as-is | No |
| CHANGELOG content | Always (required for ship) | Auto-generate from diff | No |
| Commit message | Always (required for ship) | Auto-write following existing style | No |
| Multi-file changesets | Always (bisectable commits) | Auto-split into logical commits | No |
| Version bump level — MICRO | Default case | Use MICRO (4th digit) automatically | No |
| Version bump level — MINOR or MAJOR | Strong signals present (500+ lines, new features, breaking changes) | — | **Yes** — approval confirming bump level |
| Pre-landing review ASK items | Review finds judgment-call issues | — | **Yes** — one approval per batch of ASK items |
| Greptile comments | Greptile finds issues on the PR | Fix VALID ones, skip SUPPRESSED | **Yes** for FALSE POSITIVE or uncertain |
| Coverage below threshold | AI-assessed test coverage below minimum | — | **Yes** — hard gate |
| Plan items NOT DONE | PLAN.md has unchecked items | — | **Yes** — approval asking to override or block |
| Plan verification failures | Plan consistency check fails | — | **Yes** |
| Distribution pipeline missing | New artifact type with no release workflow | Defer to TODOS.md automatically | No |

---

## `/qa`

| Checkpoint | When It Triggers | Default (Paperclip) | Escalate? |
|------------|-----------------|---------------------|-----------|
| Dirty working tree | Uncommitted changes before QA starts | Stash and continue | No |
| WTF-likelihood ≤ 20% | Normal QA run | Continue autonomously | No |
| WTF-likelihood > 20% | QA complexity is escalating | — | **Yes** — approval asking whether to continue or stop |
| Hard cap at 50 fixes | 50 individual fixes reached | Stop automatically and post report | No |

**WTF-likelihood scoring:**
- Each revert: +15%
- Each fix touching > 3 files: +5%
- After fix 15: +1% per additional fix
- All remaining issues are Low severity: +10%
- Fix touches unrelated files: +20%

If WTF-likelihood stays below 20% throughout, `/qa` is fully autonomous.

---

## `/qa-only`

No checkpoints. Report-only mode — finds and documents bugs without applying fixes. Fully autonomous. Output is a structured bug report.

---

## `/investigate`

No interactive checkpoints. Root-cause debugging is fully autonomous — reads code, runs commands, traces execution. Outputs a structured investigation report with hypothesis, evidence, root cause, and recommended fix.

---

## `/land-and-deploy`

| Checkpoint | When It Triggers | Default (Paperclip) | Escalate? |
|------------|-----------------|---------------------|-----------|
| First-run dry-run validation | First deploy of this project (no deploy config found) | — | **Yes** — approval confirming deploy config is correct |
| Subsequent deploys | Deploy config already exists | Skip dry-run automatically | No |
| Inline review offer | Review is stale or missing before deploy | — | **Yes** — approval: quick review / full review / skip |
| Pre-merge readiness gate | **Always**, before every merge | — | **Yes** — always. Shows readiness report, asks to merge. |
| No deploy pipeline | No deploy config found at all | — | **Yes** — approval asking for production URL or deploy command |
| Staging-first option | Production URL is configured | Skip staging, go direct to production | No |
| Deploy failure | Deploy pipeline fails | — | **Yes** — approval: view logs / revert / continue |
| Production health issues | Canary checks fail post-deploy | — | **Yes** — approval: expected degradation / revert / investigate |

**Note:** The pre-merge readiness gate is a hard always-escalate. There is no configuration to skip it — it requires a human to approve every production deploy.

---

## `/canary`

No interactive checkpoints. Runs health checks autonomously and outputs a structured pass/fail report. If called standalone (not from within `/land-and-deploy`), posts results as an issue comment. Fully autonomous.

---

## `/autoplan`

| Checkpoint | When It Triggers | Default (Paperclip) | Escalate? |
|------------|-----------------|---------------------|-----------|
| Premise confirmation | Phase 1 (CEO review) — always | — | **Yes** — approval asking human to confirm the plan premises are correct |
| Final approval gate | Phase 4 (after all reviews) — always | — | **Yes** — approval presenting taste decisions, user challenges, and cross-phase themes |

**Cross-role phase delegation (not approvals — these are subtasks):**

| Phase | What happens in Paperclip mode |
|-------|-------------------------------|
| Design review phase | CEO creates subtask → assigns to DesignLead (`/plan-design-review`) |
| Engineering review phase | CEO creates subtask → assigns to CTO (`/plan-eng-review`) |
| DX review phase | CEO creates subtask → assigns to DevExEngineer (`/plan-devex-review`) |

The CEO sets its own task to `in_review` after creating all subtasks and waits for them to complete before proceeding to the final gate.

---

## `/cso`

No interactive checkpoints. Security audit runs fully autonomously. Outputs a structured OWASP Top 10 + STRIDE report with findings categorized by severity. Posts results as issue comments. Fully autonomous.

---

## `/devex-review`

No interactive checkpoints. DX audit runs autonomously. Outputs a structured report on developer experience quality. Fully autonomous.

---

## `/benchmark`

No interactive checkpoints. Performance regression detection runs autonomously. Compares before/after metrics and outputs a structured report. Fully autonomous.

---

## `/retro`

No interactive checkpoints. Retrospective generation runs autonomously based on git history, issue comments, and previous retro notes. Fully autonomous.

---

## `/document-release`

No interactive checkpoints. Release documentation generation runs autonomously based on CHANGELOG, PR descriptions, and commit history. Fully autonomous.

---

## `/careful` and `/guard`

No interactive checkpoints. These are configuration-setting skills that activate safety modes. `/careful` adds an extra review step before changes. `/guard` restricts edits to a specified directory. Both run and complete autonomously.

---

## Default Auto-Decide Reference

When making Tier 1 (mechanical) decisions, the bridge skill uses these defaults unless the issue description specifies otherwise:

| Decision | Default |
|----------|---------|
| Version bump level | MICRO (4th digit) |
| Dirty working tree | Stash and continue |
| AUTO-FIX review findings | Always apply all |
| TODOS.md creation | Auto-create if missing |
| TODOS.md reorganization | Leave as-is |
| Test coverage within threshold | Continue |
| Greptile VALID & ACTIONABLE | Fix it |
| Greptile SUPPRESSED | Skip it |
| Staging vs production | Go direct to production |
| Commit messages | Auto-write following existing project style |
| CHANGELOG entries | Auto-generate from diff |
| Bisectable commits | Auto-split into logical commits |
| Distribution pipeline missing | Add to TODOS.md and defer |

To override a default, include the override in the task description. Example: "Use MINOR bump — this adds a new API endpoint." The agent reads this as a Tier 3 (pre-answered) decision and uses it without creating an approval.
