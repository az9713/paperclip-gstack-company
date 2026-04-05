# gstack Skills

A deep dive into what gstack skills are, how they are structured, how they are installed and mounted, and how agents use them.

---

## What Is a Skill?

A skill is a structured prompt file (`SKILL.md`) that teaches an AI agent how to perform a specific engineering workflow. Each skill is a directory with a `SKILL.md` file at its root, optionally accompanied by reference files and sub-directories.

Skills encode opinionated, role-specific workflows with:
- Step-by-step checklists that the agent follows
- Quality gates that must pass before the agent continues
- Decision rules — which choices to make automatically vs. which require human input
- Output formats — how to structure findings, reports, and comments

A skill is not a library or API. It is a document the agent reads at the start of a workflow. The agent then follows its instructions using its own tools (Bash, Read, Write, Edit).

---

## The SKILL.md Format

Every skill file has two sections: YAML frontmatter and the skill body.

### Frontmatter

```yaml
---
name: review
preamble-tier: 1
version: 2.3.1
description: |
  Pre-landing code review. Finds bugs, performance issues, security
  vulnerabilities, and code quality problems. Categorizes findings
  as AUTO-FIX (apply immediately) or ASK (require human decision).
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---
```

| Field | Description |
|-------|-------------|
| `name` | The skill's identifier. Matches the directory name. |
| `preamble-tier` | Controls which ETHOS preamble blocks are injected (1 = full preamble). |
| `version` | Semantic version used by `gstack-upgrade` to detect when skills need updating. |
| `description` | One-paragraph description shown in skill help and documentation. |
| `allowed-tools` | The Claude Code tools this skill is permitted to use. `AskUserQuestion` is present in interactive skills but absent in fully autonomous ones. |

### Skill Body

The body is Markdown that the agent reads and follows as instructions. It typically contains:

1. **Preamble run block** — a bash script the agent runs first to detect the environment (branch, repo mode, session state, update availability)
2. **Routing rules** — how to invoke sub-skills when patterns match
3. **Step-by-step workflow** — numbered phases the agent executes in order
4. **Decision tables** — what to auto-fix vs. what to escalate
5. **Output format** — how to structure findings or reports

---

## Templates: `.tmpl` → `SKILL.md`

Most gstack SKILL.md files are **generated** from `.tmpl` template files. Never edit the generated `SKILL.md` files directly. Edit the `.tmpl` file, then regenerate:

```bash
cd gstack
bun run gen:skill-docs
```

Templates use placeholder tokens that the generator replaces:

| Token | Replaced with |
|-------|--------------|
| `{{PREAMBLE}}` | The full ETHOS preamble bash block |
| `{{BROWSE_SETUP}}` | Browser CLI setup instructions |
| `{{BASE_BRANCH_DETECT}}` | Dynamic `main`/`master` detection code |
| `{{REVIEW_CHECKLIST}}` | The full review checklist from `review/checklist.md` |
| `{{TODOS_FORMAT}}` | TODOS.md format guide |

The generator script is `gstack/scripts/gen-skill-docs.ts`. It reads all `.tmpl` files, resolves tokens via modular resolvers in `scripts/resolvers/`, and writes the corresponding `SKILL.md` files.

---

## The ETHOS Preamble

Every gstack skill that has `preamble-tier: 1` in its frontmatter gets the ETHOS preamble injected automatically. The preamble runs a bash block that detects:

- Current git branch
- gstack update availability
- Proactive mode setting (should the agent auto-invoke skills or wait for explicit invocation?)
- Skill prefix setting (namespaced `/gstack-review` vs. short `/review`)
- Repo mode (how the project is structured)
- Prior learnings (project-specific knowledge from previous sessions)
- Session timeline logging

After the bash block, the preamble establishes three builder principles from `gstack/ETHOS.md`:

**Boil the Lake** — When AI makes the marginal cost of completeness near-zero, always do the complete thing. Full test coverage, all edge cases, complete error paths. "Ship the shortcut" is legacy thinking.

**Search Before Building** — Before designing any solution, check what already exists. There are three layers of knowledge: tried-and-true patterns (Layer 1), current best practices (Layer 2), and first-principles reasoning (Layer 3). Prize Layer 3 most.

**User Sovereignty** — AI models recommend. Users decide. Even if two models agree, the user always has context the models lack. Always present recommendations and ask; never act unilaterally on judgment calls.

These three principles shape how agents reason throughout every workflow. They are not aspirational — they are operational, with concrete anti-patterns listed for each.

---

## How Skills Are Installed

### Interactive Installation (for standalone gstack use)

```bash
git clone https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup
```

The `setup` script creates per-skill directories in `~/.claude/skills/` with a `SKILL.md` symlink inside each one. Claude Code discovers these directories as registered skills and enables the corresponding slash commands.

### Paperclip Installation (for the Engineering Company)

Paperclip does not install skills to `~/.claude/skills/` permanently. Instead, the `claude_local` adapter creates an **ephemeral** skill directory for each agent run:

1. Paperclip creates a temp directory (e.g., `/tmp/paperclip-skills-abc123/`)
2. Inside it, creates `.claude/skills/`
3. Creates symlinks in `.claude/skills/` pointing to the actual skill source directories on disk
4. Passes `--add-dir /tmp/paperclip-skills-abc123` to Claude Code

Claude Code sees the temp dir as if it were a properly structured skills home. After the run, the temp directory is cleaned up. This ensures each run gets exactly the skills configured for that agent — no more, no less.

The source directories come from the skills imported into the company. When you call `POST /api/companies/{id}/skills/import` with a `source` path, Paperclip records the absolute path to the skill directory. At runtime, it creates symlinks to those recorded source paths.

### Skill Naming and the `runtimeName`

Each skill entry has a `runtimeName` — the directory name Claude Code sees. For gstack skills, this matches the skill's `name` field in the frontmatter (e.g., `review`, `qa`, `land-and-deploy`). The `key` used in `desiredSkills` configuration may be prefixed (e.g., `gstack-review`), but the runtime name is what Claude Code uses for the slash command.

---

## The Slash Command Mechanism

When Claude Code reads a skills directory, it discovers directories containing `SKILL.md` files and registers them as slash commands. A directory named `review` with a `SKILL.md` inside becomes the `/review` command. When the agent types or is instructed to run `/review`, Claude reads the corresponding `SKILL.md` and follows its instructions.

In Paperclip headless mode, the gstack-bridge skill teaches agents to invoke skills by reading the SKILL.md file directly (using the `Read` tool on the skill path) rather than typing a slash command. The effect is the same: the agent reads and follows the skill's instructions.

---

## The Skill Chain Model

Some gstack skills invoke other skills as part of their workflow. `/autoplan` is the primary example:

```
/autoplan
  Phase 1: CEO review      → runs /plan-ceo-review
  Phase 2: Design review   → runs /plan-design-review
  Phase 3: Eng review      → runs /plan-eng-review
  Phase 4: DX review       → runs /plan-devex-review
  Phase 5: Final gate      → presents consolidated findings
```

In interactive mode (single human + single Claude Code session), all phases run sequentially in the same context. The agent switches roles by reading different skill files.

In Paperclip mode, cross-role phases become subtask delegation. The CEO handles Phase 1 itself (CEO review is its own role), then creates subtasks for DesignLead (Phase 2), CTO (Phase 3), and DevExEngineer (Phase 4). See [Bridge Skill](bridge-skill.md) for the delegation protocol.

Other skill chains:
- `/ship` can trigger an inline `/review` if the branch has not been reviewed — in Paperclip, this becomes a self-assigned subtask for the CTO
- `/land-and-deploy` runs `/canary` post-deploy — in Paperclip, this runs inline since both are ReleaseEngineer's skills

---

## Interactive Checkpoints

Interactive gstack skills (those with `AskUserQuestion` in `allowed-tools`) pause at decision points and present questions to the human:

```
AskUserQuestion: "Review found 2 ASK items:
1. SQL injection risk in auth middleware - Fix now or defer?
2. Missing rate limiting on /api/login - Fix now or defer?
Options: A) Fix both now  B) Fix #1, defer #2  C) Defer both"
```

Claude waits for the human's response before continuing. This is the core of gstack's interactive model.

In Paperclip headless mode, `AskUserQuestion` cannot be called — there is no terminal. The gstack-bridge skill replaces this with the approval protocol. See [Bridge Skill](bridge-skill.md).

---

## AUTO-FIX vs ASK in `/review`

The `/review` skill categorizes every finding into one of two buckets:

**AUTO-FIX** — apply without asking:
- Dead code (unused imports, unreachable functions)
- N+1 query patterns
- Stale comments (wrong type annotations, outdated references)
- Non-functional type errors
- Missing null checks that are clearly bugs
- Code style violations

**ASK** — present to the human for a decision:
- Security vulnerabilities (always ask — scope and timing matter)
- Performance changes that require architectural discussion
- API contract changes (breaking vs. non-breaking)
- Behavior changes that affect multiple systems
- Anything where "fix now vs. file a separate PR" is genuinely unclear

The distinction is not about severity — it is about whether a reasonable engineer would make the call without asking the product owner. A SQL injection is always ASK not because it is less clear what to do, but because the timing and scope decision belongs to the human.

---

## The Headless Browser (`$B` commands)

gstack ships a headless Chromium daemon used by QA and design skills. It is compiled from `gstack/browse/` and accessible via the `$B` alias.

```bash
$B goto https://myapp.com/login    # Navigate to URL
$B snapshot                         # Take accessibility snapshot
$B click "button[type=submit]"      # Click element
$B screenshot /tmp/login.png        # Take screenshot
```

The browser daemon auto-starts on first use (~3 seconds), then responds in ~100-200ms per command. It maintains session state (cookies, localStorage, tabs) across calls within a run.

In Paperclip mode, the browser daemon is available to QAEngineer when it runs `/qa`. The agent navigates to the staging URL, interacts with the UI, takes screenshots of bugs, and includes them as evidence in its bug report.

---

## Full Skill Inventory

| Slash Command | Agent | Purpose |
|--------------|-------|---------|
| `/autoplan` | CEO | Full planning pipeline: CEO → design → eng → DX review |
| `/plan-ceo-review` | CEO | CEO-level strategic review of a plan document |
| `/office-hours` | CEO | Open-ended strategic consultation |
| `/plan-eng-review` | CTO | Engineering-level review of a plan document |
| `/review` | CTO | Pre-landing code review with AUTO-FIX/ASK categorization |
| `/ship` | CTO | Version bump, CHANGELOG, create PR |
| `/investigate` | SeniorEngineer | Systematic root-cause debugging |
| `/codex` | SeniorEngineer | Multi-AI second opinion via OpenAI Codex CLI |
| `/land-and-deploy` | ReleaseEngineer | Merge, deploy, canary monitor |
| `/canary` | ReleaseEngineer | Post-deploy health monitoring |
| `/document-release` | ReleaseEngineer | Post-ship documentation updates |
| `/setup-deploy` | ReleaseEngineer | One-time deploy configuration |
| `/devex-review` | DevExEngineer | Developer experience audit |
| `/plan-devex-review` | DevExEngineer | DX-level review of a plan document |
| `/retro` | DevExEngineer | Weekly retrospective from git history |
| `/benchmark` | DevExEngineer | Performance regression detection |
| `/qa-only` | QALead | Report-only QA — finds bugs without fixing |
| `/qa` | QAEngineer | Full QA loop: find, fix, verify, commit |
| `/cso` | SecurityOfficer | OWASP Top 10 + STRIDE security audit |
| `/careful` | SecurityOfficer | Enable careful mode (extra review before changes) |
| `/guard` | SecurityOfficer | Restrict edits to specific paths |
| `/design-review` | DesignLead | UI/UX design audit with fix loop |
| `/design-html` | DesignLead | Convert design mockup to HTML/CSS |
| `/design-consultation` | DesignLead | Design system creation from scratch |
| `/design-shotgun` | DesignLead | Visual exploration: generate multiple design directions |
| `/plan-design-review` | DesignLead | Design-level review of a plan document |
