# gstack + Paperclip Engineering Company

This repository combines three systems into a fully autonomous engineering team: **Paperclip** (agent orchestration), **gstack** (engineering skills), and an **Engineering Company template** that wires them together into a 9-agent team that plans, codes, reviews, ships, and monitors production — with human oversight on judgment calls.

**One sentence:** Paperclip gives agents their jobs. gstack gives agents their skills.

---

## Documentation

### Overview

| Document | Description |
|----------|-------------|
| [What is this?](overview/what-is-this.md) | Conceptual overview of Paperclip, gstack, and the Engineering Company. Start here. |
| [Key concepts](overview/key-concepts.md) | Glossary of every important term: Skill, Company, Agent, Issue, Approval, Bridge Skill, and more. |

### Getting Started

| Document | Description |
|----------|-------------|
| [Prerequisites](getting-started/prerequisites.md) | Exact requirements: Node.js, pnpm, Bun, Anthropic API key, Claude Code CLI. |
| [Quickstart](getting-started/quickstart.md) | Clone, install, start the server, provision the engineering company, create your first task. Under 15 minutes. |
| [Onboarding](getting-started/onboarding.md) | Zero-to-hero guide for readers new to AI agents, gstack, and Paperclip. Conceptual walkthrough with no commands required. |

### Concepts

| Document | Description |
|----------|-------------|
| [gstack Skills](concepts/gstack-skills.md) | What SKILL.md files are, how skills are mounted, the checkpoint system, AUTO-FIX vs ASK, and the ETHOS preamble. |
| [Paperclip Platform](concepts/paperclip-platform.md) | Company model, issue lifecycle, heartbeat scheduling, approvals, budget tracking, session continuity. |
| [Bridge Skill](concepts/bridge-skill.md) | How `gstack-bridge` solves the headless/interactive mismatch: checkpoint tiers, approval protocol, resume protocol, delegation. |
| [Engineering Company](concepts/engineering-company.md) | The 9-agent team, each agent's role and skills, typical task flows, and an end-to-end "Build auth feature" example. |

### Guides

| Document | Description |
|----------|-------------|
| [Provision the Engineering Company](guides/provision-engineering-company.md) | Run setup.sh, verify it worked, troubleshoot the three most common failures. |
| [Create and Assign Tasks](guides/create-and-assign-tasks.md) | Create tasks via UI and API, write effective task descriptions, understand task hierarchy. |
| [Handle Approvals](guides/handle-approvals.md) | Find pending approvals, read checkpoint questions, approve or reject, understand what happens next. |
| [Add a New Agent](guides/add-a-new-agent.md) | Add an agent to the engineering company: pick a role, choose skills, write onboarding docs, register, verify. |
| [Add a Custom Skill](guides/add-a-custom-skill.md) | Write a SKILL.md, import it into a company, assign it to an agent, and test it. |

### Reference

| Document | Description |
|----------|-------------|
| [company.json](reference/company-json.md) | Complete field reference for the Engineering Company configuration file. |
| [Bridge Skill API](reference/bridge-skill-api.md) | Every API call the gstack-bridge skill makes: endpoints, request/response schemas, error cases. |
| [Checkpoint Map](reference/checkpoint-map.md) | Every gstack skill, every checkpoint, auto-decide default, and whether it creates an approval. |
| [Environment Variables](reference/environment-variables.md) | Every environment variable Paperclip injects at runtime, with examples and usage. |

### Architecture

| Document | Description |
|----------|-------------|
| [System Design](architecture/system-design.md) | Three-layer architecture, skill mounting, session continuity, approval wake loop, data flow. |
| [ADR 001: Bridge Skill](architecture/adr/001-bridge-skill-not-adapter-patch.md) | Why the integration lives in a prompt-layer skill, not in the adapter or gstack templates. |
| [ADR 002: Multi-Agent](architecture/adr/002-multi-agent-not-single-agent.md) | Why each role is a separate agent, not a single agent with all skills. |

### Troubleshooting and Contributing

| Document | Description |
|----------|-------------|
| [Common Issues](troubleshooting/common-issues.md) | Top 10 problems and fixes: server not starting, agents not waking, approvals not working, and more. |
| [Contributing](../contributing.md) | Repo structure, test commands, known pre-existing issues, PR checklist. |
