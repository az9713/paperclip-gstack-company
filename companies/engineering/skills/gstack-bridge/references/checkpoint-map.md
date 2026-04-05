# gstack Skill Checkpoint Map

Per-skill inventory of all checkpoints. For each: when it triggers, the default autonomous answer in Paperclip mode, and whether to escalate to a Paperclip approval.

---

## `/review`

| Checkpoint | When it triggers | Default (auto) | Escalate? |
|------------|-----------------|----------------|-----------|
| ASK items — fix vs. skip | Review finds issues needing judgment (not auto-fixable) | — | **Yes** — one approval listing all ASK items with options |
| Greptile VALID & ACTIONABLE | Greptile finds a real issue | Fix it | No (auto-fix) |
| Greptile FALSE POSITIVE | Greptile comment appears wrong | — | **Yes** — approval asking human to confirm |
| No ASK items | Everything was AUTO-FIX | Skip — no checkpoint | No |

**Note:** AUTO-FIX items (dead code, N+1 queries, stale comments, type errors) are always applied automatically.

---

## `/ship`

| Checkpoint | When it triggers | Default (auto) | Escalate? |
|------------|-----------------|----------------|-----------|
| Distribution pipeline missing for new artifact | New artifact type with no release workflow | Defer to TODOS.md | No — auto-add to TODOS |
| Pre-landing review ASK items | Review finds judgment-call issues | — | **Yes** — one approval per batch of ASK items |
| Greptile comments | Greptile finds issues on the PR | Fix VALID ones, skip SUPPRESSED | **Yes** for FALSE POSITIVE/uncertain |
| Coverage below threshold | AI-assessed coverage below minimum | — | **Yes** — hard gate |
| Plan items NOT DONE | PLAN.md has unchecked items | — | **Yes** — approval asking to override |
| Plan verification failures | Plan check finds inconsistencies | — | **Yes** |
| MINOR or MAJOR version bump | Diff signals feature or breaking change | Use MICRO (auto) | **Yes** if signals are strong (500+ lines, breaking change) |
| TODOS.md missing | No TODOS.md found | Create it automatically | No |
| TODOS.md disorganized | TODOS.md structure is poor | Leave as-is | No |
| Uncommitted changes | Dirty working tree | Always include them | No |
| CHANGELOG content | Always | Auto-generate from diff | No |
| Commit message | Always | Auto-write | No |
| Multi-file changesets | Always | Auto-split into bisectable commits | No |

---

## `/qa`

| Checkpoint | When it triggers | Default (auto) | Escalate? |
|------------|-----------------|----------------|-----------|
| Dirty working tree | Uncommitted changes before QA starts | Stash and continue | No |
| WTF-likelihood > 20% | Too many reverts, files touched, fixes piling up | — | **Yes** — approval asking whether to continue |
| Hard cap at 50 fixes | 50 fixes reached | Stop and report | No (auto-stop) |

**WTF-likelihood scoring:**
- Each revert: +15%
- Each fix touching >3 files: +5%
- After fix 15: +1% per additional fix
- All remaining Low severity: +10%
- Touching unrelated files: +20%

If WTF-likelihood stays below 20%, `/qa` runs fully autonomous.

---

## `/qa-only`

No checkpoints. Report-only mode — finds and documents bugs without fixing them. Fully autonomous. Output is a structured bug report which QA Lead uses to create subtasks for QA Engineer.

---

## `/investigate`

No interactive checkpoints. Investigation is fully autonomous — reads code, runs commands, traces root cause. Outputs a structured investigation report. Fully autonomous.

---

## `/land-and-deploy`

| Checkpoint | When it triggers | Default (auto) | Escalate? |
|------------|-----------------|----------------|-----------|
| First-run dry-run validation | First deploy of this project | — | **Yes** — approval confirming deploy config is correct |
| Inline review offer | Review is stale or missing | — | **Yes** — approval: quick review / full review / skip |
| Pre-merge readiness gate | Always before merging | — | **Yes** — always. Show readiness report, ask to merge |
| Deploy failure | Deploy pipeline fails | — | **Yes** — approval: view logs / revert / continue |
| Production health issues | Canary checks fail post-deploy | — | **Yes** — approval: expected / revert / investigate |
| Staging-first option | Production URL is configured | Skip to production (auto) | No |
| No deploy detected | No deploy pipeline found | — | **Yes** — approval asking for production URL |

**Note:** On subsequent deploys of the same project, the first-run dry-run is skipped automatically.

---

## `/canary`

No interactive checkpoints. Runs health checks autonomously and outputs a structured pass/fail report. If called standalone (not from `/land-and-deploy`), creates a Paperclip comment with results.

---

## `/autoplan`

| Checkpoint | When it triggers | Default (auto) | Escalate? |
|------------|-----------------|----------------|-----------|
| Premise confirmation (Phase 1) | After CEO review — always | — | **Yes** — approval asking human to confirm premises are correct |
| Final approval gate (Phase 4) | After all review phases — always | — | **Yes** — approval presenting taste decisions, user challenges, and cross-phase themes |

**Note:** `/autoplan` chains CEO → design → eng → DX review phases. In Paperclip, each cross-role phase becomes a **delegated subtask** (see bridge skill Step 6) rather than running inline.

Phases where delegation applies:
- Design review phase → subtask to DesignLead
- Eng review phase → subtask to CTO
- DX review phase → subtask to DevExEngineer

---

## `/cso`

No interactive checkpoints. Security audit runs autonomously. Outputs a structured OWASP + STRIDE report with findings categorized by severity. Creates Paperclip issue comments with findings. Fully autonomous.

---

## `/investigate`

No interactive checkpoints. Root-cause debugging runs autonomously. Outputs a structured investigation report with hypothesis, evidence, root cause, and recommended fix. Fully autonomous.

---

## `/devex-review`

No interactive checkpoints. DX review runs autonomously. Outputs a structured report on developer experience quality. Fully autonomous.

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

## Default Decision Reference

When auto-deciding, use these defaults unless the issue description says otherwise:

| Decision | Default |
|----------|---------|
| Version bump level | MICRO (4th digit) |
| Dirty working tree | Stash |
| AUTO-FIX review findings | Always apply |
| TODOS.md creation | Auto-create if missing |
| TODOS.md reorganization | Leave as-is |
| Test coverage in-threshold | Continue |
| Greptile VALID & ACTIONABLE | Fix it |
| Staging vs production | Go direct to production |
| Commit messages | Auto-write following existing style |
| CHANGELOG entries | Auto-generate from diff |
