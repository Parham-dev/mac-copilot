# CopilotForge Agent Catalog

Date: 2026-03-04

---

## What We Actually Have (Stop Underestimating)

The sidecar + Copilot SDK gives us **way more** than web-fetch wrappers. Every agent session gets:

| Capability | Tool | Status |
|------------|------|--------|
| **Shell execution** | `shell` / `bash` | Available now. `approveAll` permission. |
| **Full filesystem** | `read_file`, `write_file`, `edit_file`, `create_file`, `delete_file` | Available now. |
| **Directory + code search** | `list_directory`, `search_files`, `search_codebase` | Available now. |
| **Web search** | `web_search` | Available now. |
| **Web fetch** | `web_fetch`, `fetch_webpage` + MCP Fetch server | Available now. |
| **MCP server infra** | `buildConfiguredMCPServers()` — stdio MCP servers with env overrides | Infra ready. Add any MCP server. |
| **Custom tool definitions** | `defineTool()` from SDK — register arbitrary tools | Infra ready. One tool defined so far. |
| **Per-agent tool policy** | `agentToolPolicyRegistry` — native/custom/MCP class control | Working. |
| **requiredConnections** | `AgentDefinition.requiredConnections: [String]` | Field exists. Not wired to UI yet. |
| **Agent sandbox dirs** | Auto-created under `~/Library/Application Support/CopilotForge/agent-runs/<sessionId>/` | Working. |

**Key insight:** The AI has shell access. It can run `git`, `curl`, `node`, `python`, `npm`, `brew`, `jq`, `ffmpeg` — anything on the user's machine. Combined with `requiredConnections` for API keys and MCP for service integrations, these agents can **do real work**, not just summarise text.

---

## Architecture: Agent UX Modes

Not every agent is "fill form → run → read output." The agent system needs three UX modes:

### Mode 1: Run Agent (current)
Standard form → execute → structured output → history.
Good for: one-shot tasks (summarise this, draft this, generate this).

### Mode 2: Dashboard Agent
Single-page, always-on view. No "run" button — the agent runs on open, auto-refreshes, shows live state.
Good for: Slack digest, project health, notification feeds.

**Implementation:** Same `AgentDefinition` + `PromptAgentExecutionService` backend, but the SwiftUI view is a custom dashboard layout instead of `AgentRunDetailView`. The `AgentDefinition` gets a new field: `uxMode: .run | .dashboard | .setup` that controls which view is rendered.

### Mode 3: Setup-First Agent
First screen is a connection/config wizard (OAuth, API key entry, preferences). Once configured, transitions to either Run or Dashboard mode.
Good for: Anything needing API keys or OAuth tokens before first use (Slack, Replicate, social media).

**Implementation:** `requiredConnections` drives the setup screen. Each connection type has a resolver (OAuth flow, API key input, file path picker, etc.). Connection state persists in Keychain. Agent only shows its main view once all required connections are satisfied.

---

## Connection System (requiredConnections)

Each connection is a typed entry the app knows how to resolve:

| Connection ID | Type | Setup Flow |
|---------------|------|------------|
| `slack-oauth` | OAuth | Slack OAuth consent → store bot token in Keychain |
| `replicate-api-key` | API Key | Text field → validate against Replicate API → store in Keychain |
| `github-pat` | API Key | Already have GitHub auth. Optionally request expanded scopes. |
| `openai-api-key` | API Key | Text field → validate → Keychain |
| `custom-api` | API Key + URL | Base URL + key input for arbitrary services |

The sidecar exposes stored connection credentials to the agent session as environment variables or via a dedicated `copilotforge_credentials` custom tool, so the AI can use them in `curl` / `shell` calls or pass them to MCP servers.

---

## Agent Catalog

### 1. content-summariser ✅ (shipped)

**UX Mode:** Run

**What:** Summarise URLs, files, or pasted text into structured output.

**Tools:** `fetch_webpage`, `web_fetch`, MCP Fetch

**Status:** Built and functional.

---

### 2. github-dashboard

**UX Mode:** Dashboard (zero setup — user is already GitHub-authed)

**What:** Your GitHub activity at a glance — PRs, issues, builds, notifications. Powered by the **official GitHub MCP server** (`github/github-mcp-server`, 27.5k stars, Go binary, stdio). Uses the existing GitHub token with expanded OAuth scopes. No extra apps, no API keys, no admin approval.

**Auth:** Existing GitHub auth + one-time scope expansion (`repo read:org notifications`). Automatic re-auth prompt if scopes are missing.

**MCP tools:** `get_me`, `list_repos`, `list_notifications`, `list_pull_requests`, `pull_request_read`, `list_issues`, `search_issues`, `list_workflow_runs`, `list_dependabot_alerts`, `list_code_scanning_alerts`

**Dashboard:** Auto-loads on open. Activity feed, PRs needing review, my open PRs, assigned issues, build status, security alerts. Repo filter sidebar.

**Full spec:** See [github-dashboard-agent.md](github-dashboard-agent.md)

---

### 3. slack-digest

**UX Mode:** Setup-First → Dashboard

**What:** Reads your Slack workspace via a **bundled local Slack MCP server** (forked from the MIT-licensed community server, 26KB). User creates a personal Slack app at api.slack.com (2 min), pastes bot token — no admin approval needed in most workspaces.

**Setup:** Paste bot token (`xoxb-...`) + team ID → validate → Keychain. No OAuth dance.

**MCP tools:** `slack_list_channels`, `slack_get_channel_history`, `slack_get_thread_replies`, `slack_get_users`, `slack_get_user_profile`

**Dashboard:** Auto-digest on open. Channel cards, decision log, action items, unresolved threads. Time range toggle.

**Full spec:** See [slack-digest-agent.md](slack-digest-agent.md)

---

### 4. social-media-creator

**UX Mode:** Setup-First → Run

**What:** Generate complete social media content packages — posts, images, carousels, short videos — from a brief. Uses Replicate for image/video generation, shell for file management, web fetch for research.

**Required connections:** `replicate-api-key`

**Setup screen:**
- Enter Replicate API key → validate → Keychain
- Select default style preferences (brand colors, tone, platform defaults)

**Inputs:**
- `brief` (text) — what you want to post about
- `platform` (select) — Twitter/X, LinkedIn, Instagram, all
- `contentType` (select) — text post, text + image, carousel, short video clip, thread
- `tone` (select) — professional, casual, provocative, educational, storytelling
- `referenceURLs` (text) — URLs for research or inspiration (optional)
- `brandGuidelines` (text) — any brand voice notes (optional)

**What the agent actually does:**
1. Researches the topic via `web_search` + `web_fetch` if reference URLs provided
2. Drafts platform-optimised copy (character limits, hashtags, formatting per platform)
3. Generates image prompts based on the content
4. Calls Replicate API via `shell` (`curl`) to generate images (SDXL, Flux, etc.)
5. Downloads generated images to agent sandbox via `shell`
6. If video requested: generates video via Replicate (Stable Video Diffusion, etc.)
7. Outputs: copy per platform + generated media files + posting schedule suggestion

**Output sections:**
- Post Copy (per platform, with character counts)
- Generated Images (saved to sandbox, displayed inline)
- Hashtags + Keywords
- Optimal Posting Times
- A/B Variants (alternative angles)

**Tools:** `shell`, `web_search`, `web_fetch`, `read_file`, `write_file`

---

### 5. standup-generator

**UX Mode:** Dashboard

**What:** Auto-generates your standup from actual git activity. Opens and shows today's report immediately — no form to fill.

**Dashboard view:**
- Today's standup (auto-generated from git log)
- Toggle: yesterday, this week
- Edit/refine before copying
- "Add note" field for non-git work (meetings, blockers)
- Copy-to-clipboard button formatted for Slack

**How it works:**
1. Agent runs `git log --author=<email> --since="yesterday"` via `shell` on active project
2. Reads open branches with `git branch -a`
3. Parses commit messages, groups by type
4. Generates standup in configured format

**Tools:** `shell` (git commands), `read_file` (for project context)

**Inputs (minimal, mostly auto-detected):**
- `projectPath` (auto-filled from active project)
- `additionalNotes` (text, optional)
- `format` (select) — classic did/doing/blockers, narrative, bullet points

---

### 6. pr-summariser

**UX Mode:** Run

**What:** Feed it a branch, get a reviewer-ready PR summary.

**Inputs:**
- `projectPath` (text) — auto-filled
- `baseBranch` (text) — main
- `compareBranch` (text) — feature branch

**What the agent does:**
1. `git diff base..compare` via `shell`
2. `git log base..compare` for commit history
3. Reads changed files via `read_file` for deeper understanding
4. Generates structured PR description

**Output:**
- Summary (2-3 sentences)
- Changes by module/area
- Risk areas + security concerns
- Testing recommendations
- Suggested review order
- Draft PR description (GitHub markdown, copy-pasteable)

**Tools:** `shell`, `read_file`, `search_codebase`

---

### 7. changelog-generator

**UX Mode:** Run

**What:** Git history between two refs → publishable release notes.

**Inputs:**
- `projectPath` (text) — auto-filled
- `fromRef` (text) — v1.0.0
- `toRef` (text) — HEAD
- `audience` (select) — developers, end users, internal
- `format` (select) — keep-a-changelog, narrative, grouped

**Agent runs:** `git log`, `git diff --stat`, reads key changed files for context.

**Tools:** `shell`, `read_file`

---

### 8. email-drafter

**UX Mode:** Run

**What:** Bullet points → polished email. Zero tool dependencies.

**Inputs:**
- `recipient` (text) — who and their role
- `keyPoints` (text) — what to say
- `intent` (select) — inform, request, follow-up, negotiate
- `tone` (select) — formal, professional, casual, diplomatic
- `replyTo` (text) — paste email you're replying to (optional)

**Output:** Subject lines (2-3), email body, alternative version, send checklist.

**Tools:** none (pure generation) — can optionally use `web_search` to research recipient's company.

---

### 9. meeting-prep

**UX Mode:** Run

**What:** Research attendees + companies + topics before a meeting.

**Inputs:**
- `meetingTopic` (text)
- `attendees` (text) — names, roles, companies
- `yourGoal` (text) — what you want from this meeting
- `meetingType` (select) — sales, partnership, investor, internal, interview

**What the agent does:**
1. `web_search` each attendee and company
2. `web_fetch` their LinkedIn, company pages, recent news
3. Cross-references to find talking points and leverage
4. Generates structured brief

**Tools:** `web_search`, `web_fetch`, `fetch_webpage`

---

### 10. competitor-intel

**UX Mode:** Run

**What:** Structured competitive analysis from public data.

**Inputs:**
- `yourProductURL` (url)
- `competitorURLs` (text) — one per line
- `comparisonAngle` (select) — features, pricing, positioning, stack, audience

**Agent runs:** Fetches all URLs, extracts features/pricing, builds comparison matrix.

**Tools:** `web_search`, `web_fetch`, `shell` (for deeper scraping if needed)

---

### 11. project-health

**UX Mode:** Dashboard

**What:** Opens and immediately shows the health of your current project — code stats, open issues patterns, test coverage trends, dependency status.

**Dashboard view:**
- Code stats: lines, languages, file count (via `shell`: `cloc`, `wc`, `find`)
- Git health: commit frequency, branch count, stale branches
- Dependency audit: `npm audit` / `pip audit` / etc. results
- TODO/FIXME/HACK scan across codebase
- Recently changed hot files
- Auto-refreshes when project changes

**Tools:** `shell`, `read_file`, `list_directory`, `search_files`, `search_codebase`

---

### 12. incident-postmortem

**UX Mode:** Run

**What:** Raw notes + timeline → structured postmortem document.

**Inputs:**
- `incidentSummary` (text)
- `timeline` (text) — paste raw notes/logs
- `impact` (text)
- `resolution` (text)
- `severity` (select)

**Output:** Structured postmortem with root cause, action items, lessons learned, communication template.

**Tools:** none (text processing). Optionally `web_search` for similar incidents / best practices.

---

### 13. api-tester

**UX Mode:** Run

**What:** Describe an API endpoint, the agent tests it end-to-end — sends requests, validates responses, generates a test report.

**Inputs:**
- `baseURL` (text) — API base URL
- `endpoint` (text) — path + method
- `headers` (text) — auth headers, content-type, etc.
- `requestBody` (text) — JSON body (optional)
- `testScenarios` (select) — happy path, error cases, edge cases, load test, all

**What the agent does:**
1. Constructs and sends HTTP requests via `shell` (`curl`)
2. Validates response codes, body structure, timing
3. Tests edge cases (missing fields, wrong types, auth failures)
4. Generates test report with pass/fail for each scenario

**Tools:** `shell` (curl), `write_file` (save responses/report)

---

### 14. doc-generator

**UX Mode:** Run

**What:** Point it at a codebase directory, it generates documentation — README, API docs, architecture overview.

**Inputs:**
- `projectPath` (text) — auto-filled
- `scope` (select) — full repo README, API docs, architecture overview, component docs
- `audience` (select) — developers, new hires, users, investors
- `existingDocs` (text) — paste current docs to update rather than replace (optional)

**What the agent does:**
1. `list_directory` + `search_codebase` to understand structure
2. `read_file` on key files (entry points, configs, main modules)
3. `shell` for `git log --oneline -20` for recent context
4. Generates docs in the requested format
5. `write_file` to save to the project

**Tools:** `shell`, `read_file`, `list_directory`, `search_codebase`, `search_files`, `write_file`

---

## Priority Order

| # | Agent | UX Mode | Why | Effort |
|---|-------|---------|-----|--------|
| 1 | **github-dashboard** | Dashboard | Zero setup — user already authed. Official MCP. Killer demo. | Medium (scope expansion + dashboard view) |
| 2 | **standup-generator** | Dashboard | Daily use. Shell + git = zero new infra. | Low |
| 3 | **pr-summariser** | Run | Every PR cycle. Shell + git. | Low |
| 4 | **email-drafter** | Run | Zero tools. Ship same day. | Trivial |
| 5 | **changelog-generator** | Run | Every release. Shell + git. | Low |
| 6 | **social-media-creator** | Setup → Run | Replicate unlock = image/video gen. | Medium (API key setup) |
| 7 | **slack-digest** | Setup → Dashboard | High value, but needs personal Slack app setup. | High (MCP fork + connection UI) |
| 8 | **meeting-prep** | Run | Web search + fetch already working. | Low |
| 9 | **project-health** | Dashboard | Always-on value. Pure shell + filesystem. | Medium (dashboard view) |
| 10 | **doc-generator** | Run | Filesystem + search already working. | Low |
| 11 | **api-tester** | Run | Shell + curl. Useful for any dev. | Low |
| 12 | **competitor-intel** | Run | Web fetch already working. | Low |
| 13 | **incident-postmortem** | Run | Pure text. | Trivial |

---

## What Needs Building (Infra)

### Must-have for Wave 1 (GitHub Dashboard)

1. **Expand OAuth scopes** — `read:user user:email` → `read:user user:email repo read:org notifications`. One-time re-auth prompt.

2. **Bundle GitHub MCP server** — Download `github-mcp-server` Go binary (darwin-arm64/amd64) from releases. Add to Xcode "Bundle Sidecar Runtime" build phase. Wire into `buildConfiguredMCPServers()` as local stdio server.

3. **Dashboard agent view** — New SwiftUI view for `uxMode: .dashboard` agents. Auto-runs on open, shows structured cards. Refreshable.

4. **`uxMode` field on AgentDefinition** — `.run` (current), `.dashboard`, `.setupFirst`. Controls which view renders.

### Must-have for Wave 2 (Connection System)

5. **Connection system UI** — `requiredConnections` drives a setup screen per agent. Keychain storage. Env var passthrough to sidecar. Needed for Slack, Replicate, and future agents.

### Already working (no new infra)

- Shell execution (`shell` / `bash`)
- File I/O (`read_file`, `write_file`, etc.)
- Web search + fetch (`web_search`, `web_fetch`, MCP Fetch)
- Code search (`search_codebase`, `search_files`)
- Agent sandbox directories
- Tool policy per agent
- Skill system (SKILL.md per agent)
- SSE streaming pipeline
- Structured output with JSON contract + repair

### Nice-to-have (Wave 3)

- **Bundled Slack MCP server** — forked community server for slack-digest
- **Background agent runs** — scheduled/periodic runs for dashboard agents
- **Agent output → clipboard / share** — direct copy or share buttons on output
- **Agent chaining** — output of one agent feeds as input to another
