# company.json Reference

Complete field reference for `companies/engineering/company.json`, the declarative definition of the Engineering Company.

> **Note:** `company.json` is used as the source of truth for `setup.sh`. It does not directly configure a running Paperclip instance — it is the reference document that `setup.sh` reads to make API calls. Edits to `company.json` take effect when `setup.sh` is re-run.

---

## Top-Level Structure

```json
{
  "company": { ... },
  "skills": [ ... ],
  "agents": [ ... ]
}
```

---

## `company` Object

Configures the company record created in Paperclip.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Display name shown in the Paperclip UI. Example: `"Engineering Co"` |
| `issuePrefix` | string | Yes | Short prefix for issue identifiers. Must be 2-6 uppercase letters. Example: `"ENG"` → issues become ENG-1, ENG-2 |
| `description` | string | No | Human-readable description of the company's purpose. |

Example:
```json
"company": {
  "name": "Engineering Co",
  "issuePrefix": "ENG",
  "description": "A fully autonomous engineering team powered by gstack skills on Paperclip."
}
```

---

## `skills` Array

Each entry defines a skill to import into the company. Skills are sourced from the local filesystem.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | Yes | The skill identifier used in agents' `desiredSkills` list. Conventionally prefixed with `gstack-` for gstack skills. Example: `"gstack-review"` |
| `sourcePath` | string | Yes | Relative path (from `company.json`) to the skill directory. Must contain a `SKILL.md` file. Example: `"../../gstack/review"` |

Example:
```json
"skills": [
  { "key": "gstack-review",  "sourcePath": "../../gstack/review" },
  { "key": "gstack-bridge",  "sourcePath": "./skills/gstack-bridge" }
]
```

The `key` does not need to match the skill's `name` field in SKILL.md frontmatter, but by convention they match (with the `gstack-` prefix added for company-level namespacing).

---

## `agents` Array

Each entry defines an agent to create in the company.

### Top-Level Agent Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | Yes | Unique identifier for the agent within `company.json`. Used for `reportsTo` cross-references. Kebab-case. Example: `"senior-engineer"` |
| `name` | string | Yes | Display name in Paperclip UI. PascalCase or plain. Example: `"SeniorEngineer"` |
| `role` | string | Yes | Functional role category. One of: `ceo`, `cto`, `cmo`, `cfo`, `engineer`, `designer`, `pm`, `qa`, `devops`, `researcher`, `general`, `manager`, `ic` |
| `title` | string | Yes | Human-readable job title. Example: `"Senior Software Engineer"` |
| `reportsTo` | string | No | The `key` of the agent this agent reports to. Null/omitted for the root agent (CEO). Example: `"cto"` |
| `capabilities` | string | Yes | Free-text description of what this agent can do. Used as context in task routing decisions. |
| `onboardingDir` | string | No | Relative path to the agent's onboarding directory. Paperclip reads all Markdown files in this directory and includes them in the agent's system prompt at runtime. |
| `adapterType` | string | Yes | The adapter that runs this agent. For the Engineering Company: always `"claude_local"` |
| `adapterConfig` | object | Yes | Adapter-specific configuration. See below. |
| `desiredSkills` | string[] | No | List of skill keys to mount for this agent. Each key must match a `key` in the `skills` array. Always include `"paperclip"` and `"gstack-bridge"`. |
| `heartbeat` | object | No | Heartbeat schedule configuration. See below. |

### `adapterConfig` Fields (for `claude_local`)

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `model` | string | No | `"claude-sonnet-4-6"` | Claude model ID to use for this agent. Options: `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-6` |
| `maxTurnsPerRun` | number | No | 0 (unlimited) | Maximum number of Claude turns in a single run. Prevents runaway loops. |
| `timeoutSec` | number | No | 0 (no timeout) | Maximum wall-clock seconds for a run before it is killed. |
| `dangerouslySkipPermissions` | boolean | No | `true` | Pass `--dangerously-skip-permissions` to Claude. Required for headless operation — without it, Claude will prompt for permission and the run will hang. |
| `onboardingDir` | string | No | — | Absolute path to the onboarding directory. At runtime, the adapter reads all `.md` files in this directory and injects them via `--append-system-prompt-file`. Note: when specified in `company.json` as a relative path, `setup.sh` expands it to an absolute path before sending to the API. |
| `heartbeat.schedule` | string | No | — | Cron expression for the agent's heartbeat schedule. Example: `"*/15 * * * *"` (every 15 minutes) |
| `paperclipSkillSync.desiredSkills` | string[] | No | — | List of skill keys to mount. Equivalent to the top-level `desiredSkills` field; this is the nested form used in `adapterConfig` when passed directly to the API. |
| `cwd` | string | No | — | Absolute path to use as the working directory for Claude Code runs. |
| `command` | string | No | `"claude"` | The command used to invoke Claude Code. Override if Claude Code is not in PATH. |
| `extraArgs` | string[] | No | — | Additional CLI arguments appended to every Claude Code invocation. |
| `env` | object | No | — | Additional environment variables injected into every run. Key-value pairs of strings. |
| `effort` | string | No | — | Reasoning effort level passed via `--effort`. One of: `low`, `medium`, `high`. |
| `chrome` | boolean | No | `false` | Pass `--chrome` to Claude Code (enables Chrome integration). |

### `heartbeat` Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schedule` | string | Yes | Cron expression for wake frequency. Examples: `"*/15 * * * *"` (every 15 min), `"0 */4 * * *"` (every 4 hours), `"0 0 * * *"` (daily at midnight) |

---

## Complete Agent Example

```json
{
  "key": "cto",
  "name": "CTO",
  "role": "manager",
  "title": "Chief Technology Officer",
  "reportsTo": "ceo",
  "capabilities": "Engineering management, code review, release management, technical planning",
  "onboardingDir": "./onboarding/cto",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-sonnet-4-6",
    "maxTurnsPerRun": 150,
    "timeoutSec": 1800,
    "dangerouslySkipPermissions": true
  },
  "desiredSkills": [
    "paperclip",
    "gstack-bridge",
    "gstack-plan-eng-review",
    "gstack-review",
    "gstack-ship"
  ],
  "heartbeat": { "schedule": "*/20 * * * *" }
}
```

---

## Model Selection

| Agent | Model | Rationale |
|-------|-------|-----------|
| CEO | `claude-opus-4-6` | Highest-stakes decisions: what to build, who to assign, when to escalate |
| All others | `claude-sonnet-4-6` | Balances capability and cost for implementation-focused work |

You can change models per agent. `claude-haiku-4-6` is available for high-frequency, low-complexity agents where cost is a concern.

---

## Timeout and Turn Limits

| Agent | `maxTurnsPerRun` | `timeoutSec` | Rationale |
|-------|-----------------|-------------|-----------|
| CEO | 80 | 900 (15 min) | Triage and delegation — bounded work |
| CTO | 150 | 1800 (30 min) | Review + ship workflows can be involved |
| SeniorEngineer | 200 | 1800 (30 min) | Implementation can require many read-write cycles |
| ReleaseEngineer | 200 | 1800 (30 min) | Deploy pipelines can have many steps |
| DevExEngineer | 150 | 1200 (20 min) | Reviews and retros are structured but bounded |
| QALead | 150 | 1200 (20 min) | Report-only QA is bounded |
| QAEngineer | 200 | 1800 (30 min) | Full QA loop with browser can be long |
| SecurityOfficer | 150 | 1200 (20 min) | Security audits are systematic and bounded |
| DesignLead | 150 | 1200 (20 min) | Design reviews are bounded |

If an agent regularly hits `maxTurnsPerRun`, consider: is the task scope appropriate? Is the agent doing work it should be delegating? Increase the limit only after investigating.
