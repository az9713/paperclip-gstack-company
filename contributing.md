# Contributing

How to contribute to the gstack + Paperclip + Engineering Company codebase.

---

## Repo Structure

```
gstack_paperclip/
├── gstack/                    # gstack skills framework (external repo, vendored)
├── paperclip/                 # Paperclip orchestration platform
│   ├── packages/
│   │   ├── shared/            # Shared types and constants
│   │   ├── db/                # Database layer (drizzle-orm + embedded PostgreSQL)
│   │   ├── adapters/          # Agent adapters (claude_local, codex_local, etc.)
│   │   └── adapter-utils/     # Shared adapter utilities
│   ├── server/                # API server
│   ├── ui/                    # React web UI
│   └── cli/                   # CLI tools
├── companies/
│   └── engineering/           # Engineering Company template
│       ├── company.json       # Declarative company definition
│       ├── setup.sh           # Provisioning script
│       ├── skills/            # Company-specific skills (gstack-bridge)
│       └── onboarding/        # Per-agent onboarding bundles
└── docs/                      # This documentation
```

---

## Which Codebase Owns What

| Concern | Codebase | Notes |
|---------|----------|-------|
| gstack skill workflows, quality gates, ETHOS | `gstack/` | Do not modify for Paperclip integration — use bridge skill |
| Agent adapter (how Claude is invoked, skill mounting) | `paperclip/packages/adapters/claude-local/` | |
| Approval types, issue statuses, agent roles | `paperclip/packages/shared/src/constants.ts` | `gstack_checkpoint` type is defined here |
| API server routes | `paperclip/server/` | |
| Web UI | `paperclip/ui/` | |
| Headless/interactive bridge logic | `companies/engineering/skills/gstack-bridge/SKILL.md` | The right place for gstack-Paperclip integration |
| Checkpoint-to-approval mapping | `companies/engineering/skills/gstack-bridge/references/checkpoint-map.md` | |
| Agent onboarding bundles | `companies/engineering/onboarding/` | |
| Company provisioning | `companies/engineering/setup.sh` | |

**Do not modify `gstack/` for Paperclip integration concerns.** The bridge skill is the correct integration layer. gstack is an independent open-source project used without Paperclip by many people. Adding Paperclip-specific code to gstack couples two systems that should remain independent. See [ADR 001](docs/architecture/adr/001-bridge-skill-not-adapter-patch.md).

---

## Running Tests

### Paperclip

```bash
cd paperclip

# Run all tests (non-DB)
pnpm test:run --project server --project ui --project cli

# Run specific package
pnpm test:run --project server

# Run in watch mode
pnpm test
```

**Known issue:** 54 DB-dependent tests in `packages/db` fail due to a pre-existing `drizzle-orm` ESM circular dependency. This is not caused by changes in this repo. Run the test suites that exclude `packages/db` to get a clean signal. Do not increase the failing test count beyond 54.

```bash
# Verify the count stays at 54 (not higher):
pnpm test:run 2>&1 | grep "failed" | tail -1
```

### gstack

```bash
cd gstack

# Run free tests (skill validation, snapshot tests) — run before every commit
bun test

# Run paid evals (LLM-judge quality tests, ~$4/run) — run before shipping
bun run test:evals
```

The free tests (`bun test`) are fast (<2s) and must pass before every commit. The paid evals are diff-based and only run tests relevant to changed files.

### Skill validation (free)

```bash
cd gstack
bun run skill:check   # health dashboard for all skills
```

---

## Making Changes to the Engineering Company

### Add a new gstack skill assignment to an existing agent

1. Edit the agent's `desiredSkills` in `company.json`
2. Update the agent's onboarding `AGENTS.md` to document the new skill
3. If the new skill has new checkpoints, update `skills/gstack-bridge/references/checkpoint-map.md`
4. Apply the change to a running instance:
   ```bash
   curl -X PATCH http://localhost:3100/api/agents/<AGENT_ID> \
     -H "Content-Type: application/json" \
     -d '{"adapterConfig": {"paperclipSkillSync": {"desiredSkills": [...]}}}'
   ```

### Add a new agent

See [Add a New Agent](docs/guides/add-a-new-agent.md) for the full process. After adding, update `company.json` for reproducibility.

### Modify the bridge skill

The bridge skill is in `companies/engineering/skills/gstack-bridge/SKILL.md`. Changes take effect on the next agent run — no server restart needed, since skills are mounted ephemerally on each run.

Test changes by:
1. Creating a test task that exercises the checkpoint or protocol you changed
2. Checking the run logs and issue comments to verify the agent's behavior

When adding support for checkpoints in a new gstack skill, update:
- `SKILL.md`: add the new checkpoint to the "Select the correct gstack skill" mapping (Step 2) and the checkpoint decision tiers (Step 3)
- `references/checkpoint-map.md`: add the new skill's checkpoint table

---

## Adding a New gstack Skill to the Engineering Company Library

When gstack releases a new skill that you want available to Engineering Company agents:

1. Add it to the `skills` array in `company.json`:
   ```json
   { "key": "gstack-new-skill", "sourcePath": "../../gstack/new-skill" }
   ```

2. Import it into a running company:
   ```bash
   curl -X POST http://localhost:3100/api/companies/<COMPANY_ID>/skills/import \
     -H "Content-Type: application/json" \
     -d '{"source": "/absolute/path/to/gstack/new-skill"}'
   ```

3. Assign it to the appropriate agent's `desiredSkills`

4. Add the skill's checkpoint behaviors to `references/checkpoint-map.md` in the bridge skill

5. Update the skill-routing table in the bridge skill's `SKILL.md` (Step 2)

---

## Commit Format

Commits should be:
- **Atomic** — one logical change per commit
- **Clear** — describe the change in the subject line (50 chars), with context in the body if needed
- **Testable** — each commit should leave the codebase in a working state

If you are using AI assistance to write code, include a `Co-Authored-By` line:
```
feat: add gstack-new-skill to engineering company

Added gstack-new-skill to company.json and the bridge skill's
checkpoint map. Assigned to DevExEngineer.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

If committing code that was written by a Paperclip agent, use:
```
Co-Authored-By: Paperclip <noreply@paperclip.ing>
```

---

## PR Checklist

Before submitting a pull request:

- [ ] `bun test` passes (gstack changes) or `pnpm test:run` passes excluding known-failing db tests (Paperclip changes)
- [ ] DB test failure count is not higher than 54 (pre-existing)
- [ ] `company.json` updated if agent configs changed
- [ ] Bridge skill checkpoint-map updated if new gstack skill checkpoints were added
- [ ] Onboarding bundles updated if agent roles or skills changed
- [ ] `docs/` updated if behavior changed (new environment variables, new API calls, changed defaults)
- [ ] No changes to `gstack/` for Paperclip integration concerns (use bridge skill instead)
- [ ] PR description includes: what changed, why, how to verify

For Paperclip changes, follow the [Paperclip CONTRIBUTING.md](paperclip/CONTRIBUTING.md) which requires:
- The PR template (thinking path, what changed, verification, risks)
- A Greptile 5/5 score with all comments addressed
- All tests passing and CI green

---

## Getting Help

- Open an issue in the repository for bugs or feature requests
- For gstack-specific questions: refer to [gstack's README](gstack/README.md) and CONTRIBUTING.md
- For Paperclip-specific questions: refer to [Paperclip's CONTRIBUTING.md](paperclip/CONTRIBUTING.md)
