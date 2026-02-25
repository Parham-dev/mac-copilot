# CopilotForge 🛠️
### A Lovable-style App Builder for Non-Developers, powered by your GitHub Copilot subscription

> Build real apps through conversation — no coding required.  
> Your Copilot subscription is the engine. CopilotForge is the cockpit.

---

## What Is This?

CopilotForge is a native **macOS app** (SwiftUI) that wraps the GitHub Copilot SDK into a non-developer-friendly interface.
Think Lovable or Bolt.new — but instead of charging users for AI tokens, it runs on the **GitHub Copilot subscription they already have**.

A product manager, designer, or founder can open CopilotForge, describe what they want to build, and watch a real app get generated, edited, and deployed — without touching a terminal or IDE.

---

## Core Architecture

```text
┌──────────────────────────────────────────────────────┐
│              CopilotForge (SwiftUI Mac App)         │
│                                                      │
│   Chat UI  │  File Explorer  │  Live Preview Pane   │
│                                                      │
│        ↕ XPC / Local HTTP (localhost:7878)          │
│                                                      │
│      Node.js Sidecar (bundled inside .app)          │
│      └─ @github/copilot-sdk  (npm package)          │
│      └─ Custom Tools (file write, git, deploy)      │
│      └─ MCP Servers (Supabase, GitHub, Vercel)      │
│                                                      │
│        ↕ JSON-RPC                                    │
│                                                      │
│      Copilot CLI (installed on host machine)        │
└──────────────────────────────────┬───────────────────┘
                                   │ GitHub OAuth
                                   ▼
                     GitHub Copilot API
                     (user's own subscription)
```

**Key design principle:** CopilotForge never stores or proxies a user’s AI traffic.
Every prompt goes directly from the local Copilot CLI to GitHub’s API using the user’s own token.

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Mac UI | SwiftUI | Native feel, mature ecosystem, shared models with iOS companion |
| AI Engine | GitHub Copilot SDK (`@github/copilot-sdk`) | Embeds the full Copilot CLI agentic loop |
| Sidecar Runtime | Node.js 20 (bundled) | SDK is an npm package; avoids bridge mismatch |
| UI↔Sidecar Bridge | Local HTTP (Express) or XPC | Simple, debuggable, fast |
| Code Editor (in-app) | WKWebView + Monaco Editor | Best-in-class editing experience |
| Preview Pane | WKWebView | Renders generated web apps inline |
| Auth | GitHub OAuth Device Flow | No passwords, no secrets stored in plaintext |
| Backend-as-a-service | Supabase (via MCP) | One-click DB + auth for generated apps |
| Deployment | Vercel / Netlify CLI (via Copilot tools) | Non-developer-friendly deploy |
| Companion App | SwiftUI iOS | Shared SwiftData models, monitor + approve agent actions |

---

## Phased Roadmap

### ✅ Phase 1 — GitHub Auth + First Prompt (Current)
**Goal:** Prove the core loop. User signs in with GitHub, types a prompt, and sees Copilot respond.  
**Deliverable:** Working Mac app shell that authenticates and streams a Copilot response.

#### Scope
- [x] SwiftUI app skeleton (window, sidebar, chat pane)
- [x] Node.js sidecar bundled inside the `.app` package
- [x] Sidecar launches on app start, exposes `localhost:7878`
- [x] GitHub Device Flow OAuth
- [x] Token stored securely in macOS Keychain
- [x] `POST /prompt` endpoint calls `@github/copilot-sdk`
- [x] Streaming response piped back to SwiftUI via SSE or chunked HTTP
- [x] Chat bubble UI renders streamed Copilot output

#### Suggested File Structure

```text
CopilotForge/
├── CopilotForge.xcodeproj
├── CopilotForge/
│   ├── App/
│   │   ├── Bootstrap/
│   │   │   └── mac_copilotApp.swift
│   │   └── Environment/
│   │       └── AppEnvironment.swift
│   ├── Core/
│   │   ├── Domain/
│   │   │   ├── Auth/
│   │   │   ├── Chat/
│   │   │   └── Profile/
│   │   ├── Application/
│   │   │   ├── Auth/
│   │   │   ├── Chat/
│   │   │   └── Profile/
│   │   ├── Data/
│   │   │   └── Chat/
│   │   └── Infrastructure/
│   │       ├── Auth/
│   │       ├── Chat/
│   │       ├── Profile/
│   │       └── Sidecar/
│   ├── Features/
│   │   ├── Auth/Presentation/
│   │   ├── Chat/Presentation/
│   │   ├── Profile/Presentation/
│   │   └── Shell/Presentation/
│   └── Shared/
│       └── Support/
└── sidecar/
    ├── package.json
    ├── index.js
    ├── copilot.js
    └── auth.js
```

#### Phase 1 Success Criteria
- App launches without errors
- GitHub OAuth completes (device flow, no password)
- User types “What is 2+2?” and sees streamed Copilot response
- Token survives app restart (stored in Keychain)

---

### 🔜 Phase 2 — Workspace UX Shell (Codex-style 3-pane)
**Goal:** Establish the production UX foundation before deeper generation/deploy features.

**Layout target (desktop-first):**
- Left sidebar: admin/workspace/project management
- Center pane: primary chat workflow (resizable)
- Right pane: switchable context panel (`Preview` / `Git`) (resizable)

**Build now (this phase):**
- App shell with draggable split panes
- Project-first navigation and project switching
- Local project root setup per user (workspace + project folders)
- Right pane tab switch (`Preview`, `Git`) with placeholders + empty states
- Persist selected project + pane layout state

**After this phase (same UX track):**
- Keyboard shortcuts and command palette actions
- Better onboarding and first-project flow
- Non-blocking status strip (sidecar/auth/session health)

---

### 🔜 Phase 3 — App Generation (File Writing + Preview)
**Goal:** User describes an app, Copilot writes real files to a project folder, and live preview renders.

**Build now (immediately after Phase 2):**
- Copilot SDK file-writing tools enabled (read, write, create, delete)
- Connect active chat to active local project scope
- Preview pane wired to project runtime in WKWebView

**After initial implementation:**
- Monaco Editor embedded in WKWebView for manual edits
- “Plan → Build → Review” agent flow (Copilot plan mode)
- Project state persistence (SwiftData)

---

### 🔜 Phase 4 — Deployment + MCP Integrations
**Goal:** One-click deploy. Connect to Supabase, GitHub repo, and Vercel.

- Supabase MCP server integration (tables, auth, storage via chat)
- GitHub MCP integration (create repo, commit, push)
- Vercel CLI tool integration (single-action deploy)
- Deployment status shown in companion iOS app
- Environment variable management (secrets vault, never shown to LLM)

---

### 🔜 Phase 5 — SaaS Layer + iOS Companion
**Goal:** Monetize the workflow layer (not AI token resale).

- iCloud-backed project sync across user devices
- iOS companion app: status, approvals, chat on the go
- Team workspaces for collaborative projects
- Stripe billing (hosting, advanced templates, priority support)
- Custom agents marketplace (share/sell workflows)

---

## Business Model

| Tier | Price | Includes |
|---|---:|---|
| Free | $0 | 1 active project, community templates |
| Pro | $15/mo | Unlimited projects, iCloud sync, iOS companion |
| Team | $25/seat/mo | Shared workspace, deployment pipelines, priority support |

**Positioning:** “Your company already pays for Copilot. Now use it to build, not just to code.”

---

## Prerequisites (Phase 1 Dev Setup)

```bash
# 1) Install GitHub CLI + Copilot extension
brew install gh
gh extension install github/gh-copilot

# 2) Install Node.js 20+ (bundled in final app)
brew install node@20

# 3) Install sidecar dependencies
cd sidecar && npm install

# 4) Register a GitHub OAuth App
# github.com/settings/developers -> New OAuth App
# Callback URL: x-copilotforge://oauth/callback
# Keep your Client ID

# 5) Open Xcode project
open CopilotForge.xcodeproj
```

---

## GitHub ToS Note

The Copilot SDK is published by GitHub for third-party app builders.  
Commercial use may be allowed depending on current terms; review the SDK and platform terms before public launch, especially around token handling and resale/proxying patterns.

- Copilot SDK: https://github.com/github/copilot-sdk

---

## Current Status

| Phase | Status |
|---|---|
| Phase 1 — Auth + First Prompt | ✅ Completed |
| Phase 2 — Workspace UX Shell (3-pane) | 🔨 Next Up |
| Phase 3 — File Generation + Preview | 📋 Planned |
| Phase 4 — Deploy + MCP | 📋 Planned |
| Phase 5 — SaaS + iOS | 📋 Planned |

---

Built with SwiftUI · Powered by GitHub Copilot SDK · For non-developers with ideas, not IDEs.
