# slack-digest Agent

## Overview

Dashboard agent that reads your Slack workspace and generates rolling digests — decisions, action items, thread summaries, all at a glance.

## Slack Access: The Admin Problem

**Any** Slack integration needs an app + token. The question is who creates it and who approves it.

| Approach | App creator | Admin needed? | Status |
|----------|------------|--------------|--------|
| **Official Slack MCP** (`mcp.slack.com`) | Us (CopilotForge) — must be marketplace-published | Yes, workspace admin must approve our app | Too heavy for v1 |
| **Community MCP** (`@modelcontextprotocol/server-slack`) | User creates personal app | Only if workspace has "Require App Approval" | **Deprecated** (removed from monorepo) |
| **Bundled local MCP** (fork of community server) | User creates personal app | Only if workspace requires approval | **Our approach** |

### Why "bundled local MCP" wins

- The deprecated `@modelcontextprotocol/server-slack` is MIT, 26KB, 3 files. We fork it into the sidecar.
- Runs as **local stdio** — identical to how our Fetch MCP already works. No remote HTTP, no SDK compatibility questions.
- User creates a personal Slack app at api.slack.com (2 min), adds scopes, installs it. **Many workspaces allow self-install** — no admin needed.
- We store the bot token in Keychain, pass it as env var. Zero OAuth flows for us to build in v1.
- Future: upgrade to official Slack MCP when/if CopilotForge is published to Slack Marketplace.

### Setup flow (user perspective)

1. Open slack-digest agent → sees "Connect to Slack" setup screen
2. Click "Create Slack App" → opens api.slack.com/apps in browser
3. Follow inline instructions: create app → add scopes → install to workspace → copy bot token
4. Paste bot token (`xoxb-...`) + team ID (`T...`) into CopilotForge
5. Optionally select which channels to track (or "all public")
6. Done → dashboard loads

### Bot Token Scopes Required

```
channels:history    channels:read     chat:write
reactions:write     users:read        users.profile:read
```

6 scopes. Minimal. Read-focused. No admin scopes.

### Bundled MCP Tools (from forked server)

| Tool | What it does |
|------|-------------|
| `slack_list_channels` | List public/selected channels (paginated) |
| `slack_get_channel_history` | Get recent messages from a channel |
| `slack_get_thread_replies` | Get all replies in a thread |
| `slack_get_users` | List workspace users with profiles |
| `slack_get_user_profile` | Detailed profile for a user |
| `slack_post_message` | Post a message to a channel |
| `slack_reply_to_thread` | Reply to a specific thread |
| `slack_add_reaction` | Add emoji reaction to a message |

## Agent Design

**UX Mode:** Setup-First → Dashboard

**Setup screen:** Bot token + team ID input → validate → Keychain → optional channel picker

**Dashboard (single page, no run/history):**
- Today's digest auto-generated on open
- Per-channel cards (expandable thread summaries)
- Decision log / action items / unresolved threads
- Time range toggle: today / this week / this month
- Tap thread → full conversation with AI commentary

## Implementation Plan

### Phase 1 — Bundle Slack MCP in Sidecar

**1.1 Fork the community Slack MCP server**

Copy the 3 source files from `@modelcontextprotocol/server-slack` (MIT license) into `sidecar/src/mcp/slack/`. Adapt to our build. It's a simple `@modelcontextprotocol/sdk` stdio server wrapping Slack Web API calls.

**1.2 Add to `buildConfiguredMCPServers()`**

Same pattern as the Fetch MCP — local stdio server:

```typescript
slack: {
  type: "local",
  command: "node",
  args: [resolve(__dirname, "../mcp/slack/index.js")],
  env: {
    SLACK_BOT_TOKEN: process.env.COPILOTFORGE_SLACK_BOT_TOKEN,
    SLACK_TEAM_ID: process.env.COPILOTFORGE_SLACK_TEAM_ID,
    SLACK_CHANNEL_IDS: process.env.COPILOTFORGE_SLACK_CHANNEL_IDS ?? "",
  },
  tools: ["*"],
  timeout: 30000,
}
```

Only included when `COPILOTFORGE_SLACK_BOT_TOKEN` is set.

**1.3 Tool policy**

Add to `agentToolPolicyRegistry.ts`:
- Classify `slack_*` tools as `mcp` class
- New profile `slack-digest` → allows `custom` + `mcp`, denies `native` (no shell/file needed)

### Phase 2 — Connection System (Swift)

**2.1 Connection protocol**

```swift
protocol AgentConnectionResolver {
    var connectionID: String { get }
    func isConnected() -> Bool
    func connect() async throws
    func disconnect() async throws
    func credentials() -> [String: String]
}
```

**2.2 SlackBotTokenConnectionResolver**

Simple credential entry — no OAuth dance for v1:
- Text fields for bot token (`xoxb-...`) and team ID (`T...`)
- Validate: call Slack `auth.test` with the token to confirm it works
- Store in Keychain under `copilotforge.connections.slack-bot`
- Pass to sidecar as `COPILOTFORGE_SLACK_BOT_TOKEN` + `COPILOTFORGE_SLACK_TEAM_ID`

**2.3 Setup view gating**

When `requiredConnections` is non-empty and any connection is unsatisfied, show `AgentSetupView` instead of the agent's main view.

### Phase 3 — Dashboard View (Swift)

**3.1 Add `uxMode` to AgentDefinition**

```swift
enum AgentUXMode: String, Codable {
    case run
    case dashboard
    case setupFirst
}
```

**3.2 SlackDigestDashboardView**

- On appear → triggers agent execution with defaults (today, all channels)
- Parses structured JSON into typed Swift structs
- Renders channel cards, decision log, action items — not raw markdown
- Pull-to-refresh, time range picker in toolbar

**3.3 View routing**

`AgentsEnvironment` checks `uxMode` + connection status:
- `setupFirst` + unconnected → `AgentSetupView`
- `dashboard` + connected → `SlackDigestDashboardView`
- `run` → existing `AgentRunFeatureView`

### Phase 4 — Skill & Definition

**4.1 Skill:** `skills/agents/slack-digest/SKILL.md`

Instructs AI to use `slack_*` MCP tools, group by channel/thread, extract decisions + action items, output structured JSON for card rendering, handle rate limits.

**4.2 Definition** in `BuiltInAgentDefinitionRepository`:

```swift
AgentDefinition(
    id: "slack-digest",
    name: "Slack Digest",
    description: "Auto-summarise your Slack channels.",
    allowedToolsDefault: ["slack_list_channels", "slack_get_channel_history",
                          "slack_get_thread_replies", "slack_get_users",
                          "slack_get_user_profile"],
    inputSchema: AgentInputSchema(fields: [
        .init(id: "timeRange", label: "Time Range", type: .select,
              required: true, options: ["today", "yesterday", "this week", "this month"]),
        .init(id: "focusArea", label: "Focus", type: .select,
              required: false, options: ["everything", "decisions", "action items", "mentions of me"]),
    ]),
    outputTemplate: AgentOutputTemplate(sectionOrder: [
        "Executive Summary", "Channel Digests", "Decisions",
        "Action Items", "Unresolved Threads"
    ]),
    requiredConnections: ["slack-bot"],
    optionalSkills: [
        AgentSkillRef(name: "slack-digest", description: "Slack digest guidance",
                      location: "skills/agents/slack-digest"),
        AgentSkillRef(name: "agent-json-contract", description: "JSON output contract",
                      location: "skills/shared"),
    ],
    customInstructions: nil
)
```

### Milestone Summary

| Phase | What | Depends on | Effort |
|-------|------|------------|--------|
| 1 | Fork Slack MCP + bundle in sidecar | Nothing | 1-2 days |
| 2 | Connection system (token input + Keychain + validation) | Phase 1 | 2-3 days |
| 3 | Dashboard view + uxMode routing | Phase 2 | 3-4 days |
| 4 | Skill file + agent definition | Phase 1 | 1 day |
| **Total** | | | **~8-10 days** |

Phase 1 and 4 run in parallel. Saved 2 days vs official MCP approach (no OAuth, no app registration).
