# E2E Testing with Browser Automation (chrome-devtools MCP + claude-in-chrome)

This guide documents how to use the **chrome-devtools MCP** and **claude-in-chrome** tools to perform end-to-end UI testing of complex web applications from inside a Claude Code session. It is written from direct experience testing the Paperclip Engineering Company — navigating 74 pages, observing live agent runs, reading accessibility trees, clicking UI elements, and capturing a complete screenshot archive — all within a single Claude conversation.

---

## Why This Matters

Paperclip is a multi-tenant, real-time web app where agent state changes asynchronously. Testing it manually means:
- Clicking through agent dashboards to read run logs
- Navigating issue pages to verify subtask creation
- Watching for real-time state updates (agent status, issue transitions)
- Capturing evidence of what the system did and when

Browser automation embedded in a Claude session lets you do all of this programmatically, with the AI reasoning about what it sees and making decisions — without writing a separate Playwright or Cypress test suite.

---

## Prerequisites

### 1. Chrome browser open and running

Both MCP tools connect to an already-running Chrome instance. You need Chrome open before the session starts.

### 2. claude-in-chrome extension

The `claude-in-chrome` tool requires the **Claude in Chrome** browser extension. Install it from the Chrome Web Store. Once installed, it connects to your Claude Code session via a local WebSocket bridge.

**Status check:** If `mcp__claude-in-chrome__tabs_context_mcp` returns an error or empty tab list, the extension is disconnected. Reload the extension or restart Chrome.

### 3. chrome-devtools MCP server

The `mcp__chrome-devtools__*` tools connect via the Chrome DevTools Protocol (CDP). This requires:
- The MCP server registered in your Claude Code config (`.claude/settings.json` or `CLAUDE.md`)
- Chrome running with remote debugging enabled, OR the server using the standard Chrome DevTools WebSocket endpoint

**Status check:** Try `mcp__chrome-devtools__take_snapshot` — if it returns a page snapshot, the connection is live.

### 4. Target application running

For the Paperclip tests: the Paperclip server must be running on `http://localhost:3100` (or whichever port you configured). Confirm with:
```bash
curl -s http://localhost:3100/api/health | jq .
```

### 5. A page already open in Chrome

Navigate to your application's starting URL in Chrome before beginning. The tools operate on the active tab.

---

## The Two Tool Sets: What Each Does

There are two browser automation tool families available in Claude Code. They are complementary, not redundant.

### `mcp__chrome-devtools__*`

Connects via the Chrome DevTools Protocol. Operates on the currently selected Chrome tab.

| Tool | Purpose |
|------|---------|
| `take_screenshot` | Capture a PNG of the current viewport or a specific element |
| `take_snapshot` | Read the full accessibility (a11y) tree as structured text |
| `navigate_page` | Go to a URL, go back/forward, or reload |
| `click` | Click an element by its `uid` from the a11y snapshot |
| `fill` | Fill a text input by uid |
| `list_pages` | List all open Chrome tabs |
| `select_page` | Switch to a different tab |
| `get_console_message` | Read browser console output |
| `list_network_requests` | Inspect XHR/fetch traffic |
| `evaluate_script` | Execute JavaScript in the page |

**Key characteristic:** Works reliably without a browser extension. Best for systematic page capture, navigation, and element interaction where you know the structure.

### `mcp__claude-in-chrome__*`

Connects via the Claude in Chrome browser extension, which gives it higher-level capabilities.

| Tool | Purpose |
|------|---------|
| `tabs_context_mcp` | List all open tabs with URLs and titles |
| `tabs_create_mcp` | Open a new tab |
| `navigate` | Navigate the current tab to a URL |
| `read_page` | Read page content as structured text |
| `get_page_text` | Get visible page text (simpler than a11y tree) |
| `find` | Find elements matching a CSS selector or text pattern |
| `computer` | High-level computer use (click by coordinates, type text) |
| `javascript_tool` | Execute JavaScript with the extension's context |
| `gif_creator` | Record a multi-frame GIF of a sequence of actions |
| `read_console_messages` | Read filtered console output |
| `read_network_requests` | Inspect network traffic |

**Key characteristic:** Requires the extension to be connected. Better for high-level page understanding, full-page text extraction, and GIF recording of multi-step flows.

### Which to use when

| Scenario | Recommended tool |
|---------|-----------------|
| Systematic page capture (many pages, known URLs) | `chrome-devtools` — reliable, fast |
| Reading page structure before clicking | `chrome-devtools__take_snapshot` |
| Clicking a specific tab/button by label | `chrome-devtools__click` with uid from snapshot |
| Navigating to a URL | `chrome-devtools__navigate_page` |
| Saving a screenshot to disk | `chrome-devtools__take_screenshot` with `filePath` |
| Recording a workflow as a GIF | `claude-in-chrome__gif_creator` |
| Extension disconnected / tab issues | Fall back to `chrome-devtools` |

> **Note:** During the Paperclip e2e test, `claude-in-chrome` was disconnected mid-session. All 74 screenshots were captured using `chrome-devtools` exclusively. This is the more robust choice for systematic capture workflows.

---

## Core Pattern: Snapshot → Identify UIDs → Click

The fundamental interaction loop for clicking UI elements:

### Step 1: Take a snapshot to read the page structure

```
mcp__chrome-devtools__take_snapshot
```

This returns the full accessibility tree. Every interactive element has a `uid` like `4_59`. Example output:
```
uid=4_58 tab "Dashboard"
uid=4_59 tab "Instructions" selected
uid=4_60 tab "Skills"
uid=4_61 tab "Configuration"
uid=4_62 tab "Runs"
uid=4_63 tab "Budget"
```

### Step 2: Identify the uid of the element you want to click

Read the snapshot output to find the element by its label, role, or position. The uid format is `<page_index>_<element_index>`.

### Step 3: Click using just the uid (no "uid=" prefix)

```
mcp__chrome-devtools__click  uid="4_60"
```

> **Critical:** Pass the uid value as-is (e.g. `4_60`), **not** with a `uid=` prefix (e.g. `uid=4_60`). The tool's `uid` parameter is the numeric string — adding `uid=` causes "Element not found" errors.

### Step 4: Take a screenshot to capture the result

```
mcp__chrome-devtools__take_screenshot  filePath="screenshot.png"
```

---

## Screenshot Capture Methodology

### Naming convention

All screenshots during the Paperclip e2e test followed this pattern:

```
paperclip_<sequence>_<company>_<page>_<detail>.png
```

Examples:
- `paperclip_32_ENGA_dashboard.png`
- `paperclip_43_ENGA_ceo_skills.png`
- `paperclip_69_ENGA_issue_1.png`

The numeric sequence prefix ensures alphabetical ordering matches the navigation order, making the archive easy to browse.

### Capturing agent tab pages

Paperclip agent pages have sub-tabs (Dashboard, Instructions, Skills, Configuration, Runs, Budget). To capture all tabs for an agent:

```
# 1. Navigate to the agent page
navigate_page  url="http://localhost:3100/ENGA/agents/ceo"

# 2. Take a snapshot to get tab UIDs
take_snapshot

# 3. Click each tab and screenshot
click  uid="4_59"   # Instructions tab
take_screenshot  filePath="paperclip_42_ENGA_ceo_instructions.png"

click  uid="4_60"   # Skills tab
take_screenshot  filePath="paperclip_43_ENGA_ceo_skills.png"

# ... repeat for Configuration, Runs, Budget
```

> **Note:** Tab UIDs change every page load. Always re-snapshot after navigation before clicking tabs. Never reuse UIDs from a previous navigation.

### Capturing all company pages

For a systematic capture of all company pages, navigate directly via URL. Paperclip's URL structure is predictable:

```
/ENGA/dashboard
/ENGA/inbox
/ENGA/issues
/ENGA/issues/new
/ENGA/issues/ENGA-1
/ENGA/projects
/ENGA/projects/<slug>/issues
/ENGA/routines
/ENGA/goals
/ENGA/agents
/ENGA/agents/<name>
/ENGA/agents/<name>/instructions
/ENGA/agents/<name>/skills
/ENGA/agents/<name>/configuration
/ENGA/agents/<name>/runs
/ENGA/agents/<name>/budget
/ENGA/org
/ENGA/skills
/ENGA/costs
/ENGA/activity
/ENGA/company/settings
/instance/settings/general
```

Navigate to each with `navigate_page` and capture with `take_screenshot`. The redirect in the response tells you the canonical URL (e.g. `/ENGA/agents` redirects to `/ENGA/agents/all`).

---

## How the Paperclip E2E Test Was Run

### Test objective

Verify the complete delegation chain: a single task assigned to the CEO agent should cascade through the org chart autonomously, with each agent creating subtasks for its reports using the Paperclip REST API.

### Test setup

1. Paperclip server running on `http://localhost:3103` (user's configured port)
2. Chrome open with Paperclip web UI loaded
3. ENGA company provisioned with 9 agents via `setup.sh`
4. All agents configured with:
   - Model: `claude-haiku-4-5-20251001`
   - `CLAUDE_CONFIG_DIR=~/.claude-paperclip` (plugin isolation)
   - `CLAUDE_CONFIG_DIR` pointing to a clean config with no plugins

### Test trigger

ENGA-1 was created manually via the Paperclip web UI ("New Issue" button), titled *"Implement user authentication with email/password login"*, assigned to CEO. No other manual intervention after this point.

### Observation workflow

During the test, the following browser automation workflow was used to observe progress:

**1. Check agent run status**
```
navigate_page  url="http://localhost:3103/ENGA/agents/ceo/runs"
take_screenshot
```
The Runs tab shows a list of all runs with timestamps, trigger source (`on_demand`, `assignment`, `automation`), token count, and success/failure status.

**2. Read run detail (live thinking)**
Navigate into a specific run by clicking it in the Runs list (snapshot → get run row uid → click). The run detail page shows the agent's full turn-by-turn log — every tool call, every reasoning step.

**3. Check issue state**
```
navigate_page  url="http://localhost:3103/ENGA/issues/ENGA-1"
take_screenshot
```
Issue pages show current status, assignee, comments, and child issues. After CEO ran, ENGA-1 gained three child issues (ENGA-2, ENGA-3, ENGA-4) visible here.

**4. Verify agent assignments**
```
navigate_page  url="http://localhost:3103/ENGA/issues"
take_snapshot
```
The issues list shows all issues with their assignees. After the full cascade, all 6 issues were visible with correct agent assignments.

**5. Monitor dashboard**
```
navigate_page  url="http://localhost:3103/ENGA/dashboard"
take_screenshot
```
The dashboard shows live agent run summaries — the "recent run" card for each agent shows the last thing it said, confirming the delegation messages.

### What was verified

| Check | Method | Result |
|-------|--------|--------|
| CEO read ENGA-1 correctly | Run detail page, CEO run logs | CEO read inbox → read issue → listed agents |
| CEO created ENGA-2 (CTO) | Issues list + ENGA-2 detail page | ✅ Created with correct assigneeAgentId |
| CEO created ENGA-3 (SecurityOfficer) | ENGA-3 detail page | ✅ Created with correct assigneeAgentId |
| CEO created ENGA-4 (QALead) | ENGA-4 detail page | ✅ Created with correct assigneeAgentId |
| CTO auto-woke on assignment | CTO Runs tab | ✅ `source=assignment`, ~60s after ENGA-2 created |
| CTO created ENGA-5 (SecurityOfficer) | ENGA-5 detail page | ✅ Created with detailed security spec |
| CTO created ENGA-6 (QAEngineer) | ENGA-6 detail page | ✅ Created with API test spec |
| SecurityOfficer auto-woke | SecurityOfficer Runs tab | ✅ `source=assignment` |
| QALead auto-woke | QALead Runs tab | ✅ `source=assignment` |
| QAEngineer auto-woke | QAEngineer Runs tab | ✅ `source=assignment`, ENGA-6 QA completed |
| No banned tools used | All run logs | ✅ Only `Bash` (curl), `Read`, `Write` used |
| All API calls via curl | CEO/CTO run logs | ✅ Every delegation was a curl POST/PATCH |

### Screenshot archive

74 screenshots were captured to `~/Downloads/` covering every page of the Paperclip UI:

- Files 01–11: ENG company (legacy test company)
- Files 12–31: CEO delegation run detail, all 6 issues
- Files 32–46: ENGA dashboard + CEO agent (all tabs)
- Files 47–60: All ENGA company pages (inbox, agents, routines, goals, issues, costs, activity, settings, skills, org, new issue form, projects, company settings)
- Files 61–68: All 8 remaining agent dashboards
- Files 69–74: ENGA-1 through ENGA-6 issue detail pages

A companion index document at `~/Downloads/paperclip_screenshots_index.md` describes every screenshot with its URL and content.

---

## Debugging Techniques

### Reading agent run logs to diagnose tool use

Agent run logs are the primary debugging surface. Navigate to an agent's Runs tab, click a run, and read the tool-call trace. Look for:

- **Which tools were called:** `Bash`, `Read`, `Write` = correct. `TeamCreate`, `SendMessage`, `TodoWrite` = banned tools being used.
- **What the Bash commands were:** Expand the Bash tool calls to see the exact curl commands the agent ran.
- **Where it stopped:** The last tool call before the run ended tells you what the agent was doing when it exited.

### Using the accessibility tree to find dynamic elements

When page structure is dynamic (e.g. a run list where rows appear after agent activity), use `take_snapshot` rather than hardcoding selectors. The snapshot reflects the current DOM state and gives you fresh UIDs.

### Checking if a redirect happened

`navigate_page` returns the final URL after redirects. For example:
```
navigate_page  url="http://localhost:3103/ENGA/agents"
# Returns: 1: http://localhost:3103/ENGA/agents/all [selected]
```

This is useful for discovering the canonical form of a URL (e.g. `/ENGA/agents` → `/ENGA/agents/all`) for inclusion in documentation.

### Reading the dashboard for live agent state

The Paperclip dashboard shows a card per agent with their most recent run summary. The card text is the last thing the agent wrote to its output — this is a fast way to see "what is every agent currently doing" without navigating into each agent's runs page.

### Using network inspection to verify API calls

If you want to confirm what API requests an agent made during a run, use:
```
mcp__chrome-devtools__list_network_requests
```
Filter by `/api/` to see only Paperclip API calls. This is useful when a run log is ambiguous — the network trace shows the actual HTTP method, URL, and status code for every request.

---

## Common Pitfalls

### 1. UID prefix error

**Wrong:**
```
click  uid="uid=4_60"
```
**Right:**
```
click  uid="4_60"
```

The `uid` parameter takes the bare numeric string from the snapshot. The `uid=` prefix is part of the snapshot display format, not the value.

### 2. Stale UIDs after navigation

UIDs are generated fresh on every page load. After calling `navigate_page`, always call `take_snapshot` again before clicking anything. Never reuse UIDs from a previous snapshot.

### 3. Tab redirects

Many Paperclip URLs redirect to a canonical sub-path:
- `/ENGA/agents` → `/ENGA/agents/all`
- `/ENGA/settings` → `/instance/settings/general`
- `/ENGA/agents/ceo` → `/ENGA/agents/ceo/dashboard`

Navigate to the base URL and read the redirect in the response to know the canonical path.

### 4. Dynamic content not yet loaded

For pages with async content (agent dashboards that load run data), `take_snapshot` immediately after `navigate_page` may return skeleton state. If you see placeholder content, add a short wait or check for a loading indicator UID before taking the screenshot.

### 5. Extension disconnected mid-session

`claude-in-chrome` can disconnect if the extension is reloaded or Chrome is backgrounded. When this happens, `tabs_context_mcp` returns an error. Switch to `chrome-devtools` tools — they use CDP directly and are more resilient to extension state changes.

### 6. Screenshot file paths on Windows

Use forward slashes in `filePath`, even on Windows:
```
# Correct:
filePath="C:/Users/simon/Downloads/paperclip_42_ENGA_ceo.png"

# Wrong (may fail silently):
filePath="C:\\Users\\simon\\Downloads\\paperclip_42_ENGA_ceo.png"
```

---

## Reusable Test Patterns

### Pattern: Capture all tabs on an agent page

```
# Navigate to agent
navigate_page url="<base>/ENGA/agents/<name>"

# Get tab UIDs
take_snapshot

# Loop through tabs (snapshot gives you UIDs for Dashboard, Instructions, Skills, Configuration, Runs, Budget)
# For each tab uid in [dashboard_uid, instructions_uid, skills_uid, config_uid, runs_uid, budget_uid]:
click uid="<tab_uid>"
take_screenshot filePath="<prefix>_<tab_name>.png"
```

### Pattern: Verify issue was created with correct assignee

```
navigate_page url="<base>/ENGA/issues/<ISSUE_ID>"
take_snapshot
# Read snapshot: look for assignee field, parent field, status field
take_screenshot filePath="issue_<id>_verification.png"
```

### Pattern: Confirm no banned tools in a run

```
navigate_page url="<base>/ENGA/agents/<name>/runs"
take_snapshot
# Click the most recent run (get its uid from snapshot)
click uid="<run_row_uid>"
take_screenshot filePath="run_detail.png"
# Read run log — search for TeamCreate, SendMessage, TodoWrite, Agent tool
# If found: agent is using banned tools
# If only Bash/Read/Write: agent is behaving correctly
```

### Pattern: Full company page archive

```
# For each page URL in the list below, navigate and screenshot:
pages = [
  "/ENGA/dashboard",
  "/ENGA/inbox",
  "/ENGA/issues",
  "/ENGA/issues/new",
  "/ENGA/projects",
  "/ENGA/routines",
  "/ENGA/goals",
  "/ENGA/org",
  "/ENGA/skills",
  "/ENGA/costs",
  "/ENGA/activity",
  "/ENGA/company/settings",
  "/instance/settings/general",
  "/ENGA/agents",
]

# For each agent: navigate to /ENGA/agents/<name> and capture all tabs
agents = ["ceo", "cto", "seniorengineer", "securityofficer", "qalead", "qaengineer", "designlead", "devexengineer", "releaseengineer"]

# For each issue: navigate to /ENGA/issues/<ISSUE_ID>
issues = ["ENGA-1", "ENGA-2", "ENGA-3", "ENGA-4", "ENGA-5", "ENGA-6"]
```

---

## Full Test Run Timeline (Paperclip E2E)

For reference, the complete timeline of the observed test run:

| Time (approx) | Event | Observed via |
|---------------|-------|-------------|
| T+0 | ENGA-1 created, assigned to CEO | New Issue UI |
| T+0 | CEO manual wakeup triggered (`source=on_demand`) | CEO Runs tab |
| T+2 min | CEO run completes — ENGA-2/3/4 created | CEO run detail, Issues list |
| T+3 min | CTO wakes (`source=assignment`, ENGA-2) | CTO Runs tab |
| T+4 min | SecurityOfficer wakes (`source=assignment`, ENGA-3) | SecurityOfficer Runs tab |
| T+5 min | QALead wakes (`source=assignment`, ENGA-4) | QALead Runs tab |
| T+5 min | CTO run completes — ENGA-5/6 created | CTO run detail |
| T+6 min | SecurityOfficer wakes again (`source=assignment`, ENGA-5) | SecurityOfficer Runs tab |
| T+8 min | QAEngineer wakes (`source=assignment`, ENGA-6) | QAEngineer Runs tab |
| T+10 min | QAEngineer run completes — ENGA-6 QA done | QAEngineer run detail |
| Final | 6 issues, 5 agents ran, ENGA-2 marked done | Dashboard, Issues list |

All assignment-triggered wakeups fired within ~60 seconds of the assigneeAgentId being set — no manual triggers were needed after the initial CEO wakeup.

---

## See Also

- [End-to-End Test Report](../end-to-end-test-report.md) — what the agents did, the delegation chain, infrastructure fixes required
- [Common Issues #11](../troubleshooting/common-issues.md#11-agent-ignores-agentsmd--uses-teamcreate--sendmessage--todowrite-instead-of-curl) — plugin hijacking: how to diagnose and fix with `CLAUDE_CONFIG_DIR`
- [Common Issues #12](../troubleshooting/common-issues.md#12-patch-apicompaniescompanyidagentsid-returns-404) — correct PATCH endpoint for agent config updates
- [Environment Variables](../reference/environment-variables.md) — what Paperclip injects into each agent run
- Screenshot archive index: `~/Downloads/paperclip_screenshots_index.md`
