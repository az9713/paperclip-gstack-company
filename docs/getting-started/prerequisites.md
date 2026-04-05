# Prerequisites

Everything you need before running the gstack + Paperclip Engineering Company.

---

## Required Tools

### Node.js 20+

Used by the Paperclip server and its packages.

**Verify:**
```bash
node --version
# Expected: v20.x.x or higher
```

**Install:** [nodejs.org/en/download](https://nodejs.org/en/download) — use the LTS installer for your platform, or use a version manager:
```bash
# Using nvm
nvm install 20
nvm use 20

# Using fnm
fnm install 20
fnm use 20
```

---

### pnpm 9+

The package manager for the Paperclip monorepo. npm and yarn are not supported.

**Verify:**
```bash
pnpm --version
# Expected: 9.x.x or higher
```

**Install:**
```bash
npm install -g pnpm
```

Or via the standalone installer:
```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

---

### Bun

The JavaScript runtime and package manager for gstack. Used to build gstack binaries and run gstack scripts.

**Verify:**
```bash
bun --version
# Expected: 1.x.x or higher (any 1.x version works)
```

**Install:** [bun.sh](https://bun.sh)
```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash

# Windows
powershell -c "irm bun.sh/install.ps1 | iex"
```

---

### Anthropic API Key

Required for running Claude Code agents. The `claude_local` adapter passes this to Claude via the environment.

**Verify:**
```bash
echo $ANTHROPIC_API_KEY
# Expected: a non-empty string starting with "sk-ant-"
```

**Get one:** [console.anthropic.com](https://console.anthropic.com) → API Keys → Create Key

**Set it:**
```bash
# Add to your shell profile (~/.zshrc, ~/.bashrc, etc.)
export ANTHROPIC_API_KEY="sk-ant-..."
```

> **Note:** The key must be accessible in the environment where Paperclip runs. Paperclip passes it to Claude Code subprocesses automatically via the `claude_local` adapter.

---

### Claude Code CLI

The `claude` command-line tool used by the `claude_local` adapter to run agents.

**Verify:**
```bash
claude --version
# Expected: 1.x.x or higher
```

**Install:** [docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code)
```bash
npm install -g @anthropic-ai/claude-code
```

After installing, authenticate:
```bash
claude login
```

---

### Git

Required to clone the repository and for agents to commit code.

**Verify:**
```bash
git --version
# Expected: 2.x.x or higher
```

**Install:** [git-scm.com/downloads](https://git-scm.com/downloads) or via your package manager:
```bash
# macOS
brew install git

# Ubuntu/Debian
sudo apt-get install git

# Windows
winget install Git.Git
```

---

### jq

The JSON processor used by `setup.sh` to parse API responses during provisioning.

**Verify:**
```bash
jq --version
# Expected: jq-1.6 or higher
```

**Install:**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows
winget install jqlang.jq
```

---

## Summary

| Tool | Minimum Version | Check Command |
|------|----------------|---------------|
| Node.js | 20.x | `node --version` |
| pnpm | 9.x | `pnpm --version` |
| Bun | 1.x | `bun --version` |
| Claude Code CLI | 1.x | `claude --version` |
| Git | 2.x | `git --version` |
| jq | 1.6 | `jq --version` |
| Anthropic API Key | — | `echo $ANTHROPIC_API_KEY` |

All six tools must be present and the API key must be set before proceeding. If any are missing, the install steps for the missing tools will fail with a clear error.

---

## Disk Space

The Paperclip monorepo with `node_modules` takes approximately 800 MB. gstack with binaries takes approximately 200 MB. Allow at least 1.5 GB free.

---

## Next Steps

[Quickstart](quickstart.md) — clone, install, and run your first task in under 15 minutes.
