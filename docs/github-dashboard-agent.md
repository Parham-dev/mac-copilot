# github-dashboard Agent

## Overview

Dashboard agent powered by the **official GitHub MCP server** (`github/github-mcp-server`). User is already signed in with GitHub — we just expand OAuth scopes and bundle the MCP binary. No extra apps, no admin approval, no API keys.

## Why This Is the Best First Agent

1. **User is already authenticated** — GitHub device flow is done
2. **Only change:** expand scopes from `read:user user:email` → add `repo read:org notifications`
3. **Official MCP server** from GitHub (27.5k stars, MIT, Go binary, stdio mode)
4. **Local stdio** — same pattern as our existing Fetch MCP server
5. **Zero friction** — user re-auths once, everything works

## GitHub MCP Server

| | |
|---|---|
| **Repo** | `github/github-mcp-server` (27.5k stars) |
| **Binary** | `github-mcp-server stdio` (Go, pre-built releases) |
| **Transport** | stdio (local) — exact same as Fetch MCP |
| **Auth** | `GITHUB_PERSONAL_ACCESS_TOKEN` env var (our OAuth token works) |
| **Config** | Toolsets via `GITHUB_TOOLSETS` env var |
| **Read-only** | `GITHUB_READ_ONLY=1` for safe dashboard use |

### Default Toolsets (what user gets out of the box)

| Toolset | Key tools |
|---------|-----------|
| **context** | `get_me` — current user, permissions, orgs |
| **repos** | `list_repos`, `get_file_contents`, `search_code`, `list_branches`, `list_commits` |
| **issues** | `issue_read`, `list_issues`, `get_issue_comments`, `search_issues` |
| **pull_requests** | `pull_request_read`, `list_pull_requests`, `get_pull_request_diff`, `get_pull_request_reviews` |
| **users** | `get_user`, user profiles |

### Additional toolsets we enable

| Toolset | Key tools |
|---------|-----------|
| **notifications** | `list_notifications`, `mark_notification_read` |
| **actions** | `list_workflow_runs`, `get_workflow_run`, `get_workflow_run_logs` |
| **orgs** | `list_org_repos`, `list_org_members` |
| **code_security** | `list_code_scanning_alerts` |
| **dependabot** | `list_dependabot_alerts` |

### OAuth Scopes Needed

Current: `read:user user:email`

Expanded: `read:user user:email repo read:org notifications`

- `repo` — read repos, issues, PRs, code, commits, branches, actions, security alerts
- `read:org` — see org membership, teams, org repos
- `notifications` — read notification feed

User re-authenticates once via the same device flow. Consent screen shows the expanded scopes.

## Agent Design

**UX Mode:** Dashboard (single page, auto-loads on open)

**No setup screen needed** — user is already GitHub-authed. If scopes aren't sufficient, prompt a one-time re-auth.

### Dashboard Layout

```
┌─────────────────────────────────────────────────┐
│  GitHub Dashboard              [Refresh] [⚙️]    │
├──────────┬──────────────────────────────────────┤
│          │                                      │
│  Repos   │   [Activity Feed]                    │
│  ────    │   • PR #42 merged in org/api         │
│  org/api │   • Issue #128 assigned to you       │
│  org/web │   • Build failed on org/web main     │
│  my/proj │   • @alice commented on your PR      │
│          │                                      │
│  ────    │   [PRs Needing Review]               │
│  Filter  │   • org/api #51 — "Add caching"      │
│  [All]   │   • org/web #89 — "Fix login flow"   │
│  [Mine]  │                                      │
│  [Org]   │   [My Open PRs]                      │
│          │   • org/api #47 — "Refactor auth" ✅  │
│          │   • my/proj #12 — "Add tests" 🔄     │
│          │                                      │
│          │   [Issues Assigned to Me]             │
│          │   • org/api #128 — "API timeout bug"  │
│          │                                      │
│          │   [Build Status]                      │
│          │   • org/api main: ✅ passing           │
│          │   • org/web main: ❌ failing           │
│          │                                      │
└──────────┴──────────────────────────────────────┘
```

### Dashboard Sections

1. **Activity Feed** — recent notifications, comments, mentions across all repos
2. **PRs Needing My Review** — PRs where I'm requested as reviewer
3. **My Open PRs** — PRs I authored, with CI status + review status
4. **Issues Assigned to Me** — across all repos
5. **Build Status** — latest CI run per tracked repo's main branch
6. **Security Alerts** — dependabot + code scanning alerts (if any)

### Repo Sidebar

- Lists repos the user is involved with (contributed to recently or member of)
- Click a repo → filters all sections to that repo
- Filters: All / Mine / Org
- Auto-detected from `get_me` + `list_repos`

## Implementation Plan

### Phase 1 — Expand OAuth Scopes + Bundle MCP Binary

**1.1 Update auth scopes**

In `sidecar/src/auth.ts`, change:
```typescript
scope: "read:user user:email",
// →
scope: "read:user user:email repo read:org notifications",
```

On app launch, check if stored token has the old scopes (via `fetchTokenScopes()`). If missing `repo`, prompt user to re-auth once.

**1.2 Bundle GitHub MCP server binary**

- Download `github-mcp-server` from [releases](https://github.com/github/github-mcp-server/releases) (darwin-arm64 + darwin-amd64)
- Add to the Xcode "Bundle Sidecar Runtime" build phase
- Binary goes in app bundle alongside node/sidecar

**1.3 Add to `buildConfiguredMCPServers()`**

```typescript
github: {
  type: "local",
  command: resolveGitHubMCPBinaryPath(), // from app bundle
  args: ["stdio"],
  env: {
    GITHUB_PERSONAL_ACCESS_TOKEN: process.env.GITHUB_TOKEN,
    GITHUB_TOOLSETS: "default,notifications,actions,code_security,dependabot",
    GITHUB_READ_ONLY: "1",
  },
  tools: ["*"],
  timeout: 30000,
}
```

Always enabled when `GITHUB_TOKEN` is set (user is authenticated).

**1.4 Tool policy**

Add to `agentToolPolicyRegistry.ts`:
- Classify GitHub MCP tools (prefixed patterns) as `mcp` class
- Profile `github-dashboard` → allows `custom` + `mcp`, denies `native`

### Phase 2 — Dashboard View (Swift)

**2.1 Add `uxMode` to AgentDefinition** (shared with future agents)

```swift
enum AgentUXMode: String, Codable {
    case run
    case dashboard
    case setupFirst
}
```

**2.2 GitHubDashboardView**

Custom SwiftUI view:
- On appear: triggers agent execution with "generate dashboard data" prompt
- Agent uses GitHub MCP tools to fetch: notifications, PRs, issues, workflow runs
- Returns structured JSON matching dashboard card schema
- SwiftUI renders as cards/sections, not raw markdown
- Pull-to-refresh, repo filter sidebar
- Time-based auto-refresh (every 5 min optional)

**2.3 Scope check on first open**

If `fetchTokenScopes()` doesn't include `repo`, show a banner:
"GitHub Dashboard needs expanded permissions. [Re-authenticate]"
→ triggers device flow with new scopes → resumes dashboard

### Phase 3 — Agent Skill & Definition

**3.1 Skill:** `skills/agents/github-dashboard/SKILL.md`

Instructs AI to:
- Call `get_me` for user context
- Call `list_notifications` for activity feed
- Call `list_pull_requests` with reviewer filter for "PRs needing review"
- Call `list_pull_requests` with author filter for "My open PRs"
- Call `search_issues` with assignee filter for "Issues assigned to me"
- Call `list_workflow_runs` for build status per repo
- Call `list_dependabot_alerts` + `list_code_scanning_alerts` for security
- Output structured JSON with sections matching dashboard layout
- Handle pagination, rate limits, and empty states

**3.2 Definition** in `BuiltInAgentDefinitionRepository`:

```swift
AgentDefinition(
    id: "github-dashboard",
    name: "GitHub Dashboard",
    description: "Your GitHub activity at a glance — PRs, issues, builds, notifications.",
    allowedToolsDefault: [
        "get_me", "list_repos", "list_notifications",
        "list_pull_requests", "pull_request_read",
        "list_issues", "issue_read", "search_issues",
        "list_workflow_runs", "get_workflow_run",
        "list_dependabot_alerts", "list_code_scanning_alerts",
        "get_user"
    ],
    inputSchema: AgentInputSchema(fields: [
        .init(id: "repoFilter", label: "Repository", type: .select,
              required: false, options: ["all"]), // dynamically populated
        .init(id: "timeRange", label: "Time Range", type: .select,
              required: false, options: ["today", "this week", "this month"]),
    ]),
    outputTemplate: AgentOutputTemplate(sectionOrder: [
        "Activity Feed", "PRs Needing Review", "My Open PRs",
        "Issues Assigned", "Build Status", "Security Alerts"
    ]),
    requiredConnections: [], // already authed with GitHub!
    optionalSkills: [
        AgentSkillRef(name: "github-dashboard", description: "GitHub dashboard guidance",
                      location: "skills/agents/github-dashboard"),
        AgentSkillRef(name: "agent-json-contract", description: "JSON output contract",
                      location: "skills/shared"),
    ],
    customInstructions: nil
)
```

Note: `requiredConnections: []` — the user is already signed in with GitHub.

### Milestone Summary

| Phase | What | Effort |
|-------|------|--------|
| 1 | Expand scopes + bundle MCP binary + sidecar config | 2 days |
| 2 | Dashboard SwiftUI view + scope check UX | 3-4 days |
| 3 | Skill file + agent definition | 1 day |
| **Total** | | **~6-7 days** |

All phases are relatively independent. Phase 1 unblocks everything.

### Why Start Here (Not Slack)

| | GitHub Dashboard | Slack Digest |
|---|---|---|
| Auth | Already done | Needs bot token + personal app |
| Admin approval | No | Maybe (workspace policy) |
| Extra setup | One-time scope re-auth | Create Slack app + copy token |
| MCP server | Official, 27.5k stars, actively maintained | Deprecated community fork |
| User friction | Near zero | Medium |
| Effort | ~6-7 days | ~8-10 days |
