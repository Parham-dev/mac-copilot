# CopilotForge

CopilotForge is a native macOS app that provides a project-first chat workspace powered by GitHub Copilot.

- Native SwiftUI desktop shell
- Local Node sidecar for Copilot SDK integration
- Feature-first architecture (`Domain` / `Data` / `Presentation`)
- Local-first project and chat persistence


## Why CopilotForge?

The AI app builder market exploded in 2025. Lovable hit $200M ARR. Bolt crossed 5M users.
The tools work. The problem is who pays for them — and how much.

Every major AI app builder (Lovable, Bolt, v0, Replit) charges you **twice**:
once for their platform subscription, and again — implicitly — for the AI compute underneath it.
Those credit systems, token limits, and overage fees exist because they’re buying GPT-4o or
Claude Sonnet at retail API rates and passing the cost on to you.

A realistic app-building session with Claude Sonnet via API costs **$5–20 in raw tokens**.
Heavy usage — three projects a month — runs **$30–100/month** in API spend alone,
before any platform fee.

**GitHub Copilot already solved this.** For $10/month (Pro) or as part of a company-paid
Business or Enterprise seat, you get access to GPT-5, Claude Opus 4, Gemini 3 Pro, and o3 —
all through a single flat-rate subscription. 90% of Fortune 100 companies already have
Copilot Business seats. Millions of developers, PMs, and designers have Copilot paid for
by their employer and never think to use it outside an IDE.

CopilotForge puts that subscription to work for non-developers.

-----

### What Makes This Different

**It uses your Copilot subscription — not ours.**
There is no AI middleman. Your prompts go from the local sidecar directly to GitHub’s
Copilot API using your own authenticated token. We never see your traffic, we never
mark up your API costs, and your quota is yours.

**It’s a native Mac app — not another Electron wrapper.**
Every other local AI builder (Dyad, Cursor) runs on Electron or in a browser. CopilotForge
is built in SwiftUI, runs natively on Apple Silicon, and feels like it belongs on your Mac —
fast animations, system dark mode, proper window management, Keychain-stored tokens.

**It’s open source and free to use.**
The app itself costs nothing. The AI costs nothing beyond what you’re already paying for
Copilot. We only charge for managed deployment infrastructure and the iOS companion app —
the parts that genuinely require server resources to operate.

**It ships with a real workspace, not just a chat.**
Git panel, runtime manager, structured logs, AI-assisted commit messages, port conflict
resolution, multi-stack support (Node, Python, HTML) — the things non-developers
shouldn’t have to think about are handled automatically.

-----

### The Cost Comparison

|Tool             |Platform fee       |AI cost                   |Total / month|
|-----------------|-------------------|--------------------------|-------------|
|Lovable Pro      |$25                |included (capped credits) |**$25+**     |
|Bolt             |$20                |token overages common     |**$20–80+**  |
|Dyad + Claude API|free               |~$15–60 retail tokens     |**$15–60**   |
|GitHub Spark     |$39 (Pro+ required)|included                  |**$39**      |
|**CopilotForge** |**free**           |**$0** (your Copilot plan)|**$0***      |

*You pay only for deployments and the iOS companion if you want them.
If your company pays for Copilot Business or Enterprise, your AI cost is literally $0.

-----

### Who This Is For

- **PMs and designers** at companies with Copilot Business seats who want to build
  internal tools without filing a ticket with engineering
- **Founders** who have a Copilot subscription and want to validate ideas fast without
  paying Lovable out of pocket
- **Developers** who want a native Mac workspace that treats their project like a real
  codebase — not a cloud sandbox they don’t control
- **Anyone** who believes their code, their prompts, and their projects should stay on
  their machine

-----

### Why Not Just Use GitHub Spark?

GitHub Spark is GitHub’s own answer to this space — and it’s a real product. But it
requires Copilot **Pro+** ($39/month), runs entirely in the browser, is closed source,
and hosts your project on GitHub’s infrastructure. CopilotForge works with any paid
Copilot plan starting at $10/month, runs locally, is fully open source, and your code
never leaves your machine unless you choose to deploy it.

## Current Status

- Auth flow: implemented (GitHub device flow)
- Chat streaming: implemented
- Project-scoped workspace shell: implemented
- Control Center adapters (Node/Python/HTML): implemented
- Control Center runtime manager (process + health + logs): implemented
- Git panel (status, grouped changes, commit, recent commits): implemented
- AI-assisted commit message + fix-from-logs flow: implemented
- Runtime start/stop hardening (port retry, auto-free occupied port, graceful stop): implemented
- Runtime/log UX polish (copy logs, smart autoscroll, noise filtering): implemented
- Shared user-facing error mapping + non-blocking warning UX: implemented
- Typed chat event store wiring (replacing stringly NotificationCenter chat events): implemented
- Swift 6 concurrency capture hardening in runtime startup/process flows: implemented
- Chat data layer modularization (streaming, model catalog, SwiftData repository helpers): implemented
- App container modularization by feature (`AppContainer+*.swift`): implemented
- Deployment integrations (MCP/hosting): in progress

## Architecture (Feature-First)

The app is organized by feature, with each feature owning its own layers:

- `Domain`
  - `Entities`: business models
  - `Contracts`: repository and service contracts
  - `UseCases`: application business actions
- `Data`
  - local/remote implementations, transport clients, persistence adapters
- `Presentation`
  - SwiftUI MVVM views and feature UI components

Top-level structure:

```text
mac-copilot/
├── App/
│   ├── Bootstrap/
│   └── Environment/
├── Features/
│   ├── Auth/
│   │   ├── Domain/{Entities,Contracts,UseCases}
│   │   ├── Data/
│   │   └── Presentation/
│   ├── Chat/
│   │   ├── Domain/{Entities,Contracts,UseCases}
│   │   ├── Data/
│   │   └── Presentation/
│   ├── Preview/
│   │   ├── Domain/{Entities,Contracts,UseCases}
│   │   ├── Data/
│   │   └── (consumed by Shell Presentation)
│   ├── Profile/
│   │   ├── Domain/{Entities,Contracts,UseCases}
│   │   ├── Data/
│   │   └── Presentation/
│   ├── Project/
│   │   ├── Domain/{Entities,Contracts,UseCases}
│   │   └── Data/
│   ├── Shell/
│   │   ├── Domain/{Entities,Contracts,UseCases}
│   │   ├── Data/
│   │   └── Presentation/
│   └── Sidecar/
│       ├── Domain/{Entities,Contracts,UseCases}
│       └── Data/
├── Shared/
│   ├── Data/Persistence/
│   └── Support/
└── sidecar/
```

Recent architecture updates:

- App composition root split into feature extensions for clearer DI boundaries.
- Chat cross-feature UI sync now uses a typed `ChatEventsStore` instead of string keys.
- Shared `UserFacingErrorMapper` enforces consistent, production-safe user messaging.
- Large data files were split into focused helpers to keep behavior stable while improving maintainability.

## Maintainability Guardrail

- Production source files should remain at or below 300 lines to keep review and ownership manageable.
- When a source file exceeds 300 lines, split behavior into focused helper/extension files in the same feature folder.
- Scope for this guardrail: first-party app/sidecar source (`mac-copilot/**/*.swift`, `sidecar/src/**/*.ts`, `sidecar/src/**/*.js`).
- Exclusions: generated artifacts, dependency/vendor content, lockfiles, and long-form docs/runbooks.
- Suggested local check:

```bash
python3 - <<'PY'
from pathlib import Path
root = Path('.')
targets = [Path('mac-copilot'), Path('sidecar/src')]
exts = {'.swift', '.ts', '.js'}
for base in targets:
  for p in base.rglob('*'):
    if p.is_file() and p.suffix in exts:
      lines = sum(1 for _ in p.open('r', encoding='utf-8'))
      if lines > 300:
        print(f"{lines:4d} {p}")
PY
```

## Runtime Components

1. macOS app starts and initializes feature environment.
2. Sidecar lifecycle manager ensures local sidecar is healthy.
3. Swift app talks to sidecar on `127.0.0.1:7878`.
4. Sidecar executes Copilot SDK operations and streams responses.

## Control Center (Runtime)

- Project detection uses adapter-based resolution with priority fallback:
  - Node
  - Python
  - Simple HTML
- Runtime execution uses per-stack runtime adapters and a shared runtime manager.
- Control Center supports:
  - dependency install + start orchestration
  - health checks with runtime URL detection from process output
  - port conflict handling (auto-free when possible)
  - graceful stop + UI reset behavior
  - structured logs, copy logs, and AI fix handoff

Adapter/runtime source layout:

```text
mac-copilot/Features/ControlCenter/Data/
├── Adapters/
│   ├── Project/
│   └── Runtime/
├── RuntimeManager/
└── ControlCenterRuntimeUtilities.swift
```

## Requirements

- macOS (Xcode-capable development machine)
- Xcode 16+
- Node.js 22+ (requires `node:sqlite` support)
- npm
- GitHub account with Copilot access

## Local Development

1) Install sidecar dependencies

```bash
cd sidecar
npm install
```

2) Validate sidecar runtime and build

```bash
npm run check
```

For sidecar-specific details, see `sidecar/README.md`.

Optional monitoring config:

- Set `SENTRY_DSN` in your Xcode scheme environment (or build settings) to enable Sentry.
- If `SENTRY_DSN` is not set, monitoring remains disabled and the app logs a startup notice.

Auth config:

- Set `COPILOTFORGE_GITHUB_CLIENT_ID` in Xcode build settings/scheme env (wired to `GITHUB_OAUTH_CLIENT_ID` Info key).
- You can also provide `GITHUB_OAUTH_CLIENT_ID` via environment variable at runtime.
- If not configured, sign-in start will fail fast with a clear missing client ID message.

3) Open the project

```bash
open mac-copilot.xcodeproj
```

4) Run the macOS app target from Xcode

## Documentation

- Operational and release docs: [docs/README.md](docs/README.md)
- Release + Sparkle updates runbook: [docs/release-cicd-and-updates-runbook.md](docs/release-cicd-and-updates-runbook.md)
- Update button verification guide: [docs/update-button-verification.md](docs/update-button-verification.md)
- Apps platform direction (Preview/Live, versioning, customization): [README_APPS.md](README_APPS.md)
- Testing strategy and phased roadmap: [docs/testing-plan-roadmap.md](docs/testing-plan-roadmap.md)
- Chat/session history architecture: [docs/chat-session-history.md](docs/chat-session-history.md)
- iOS companion architecture and rollout phases: [docs/ios-companion-architecture.md](docs/ios-companion-architecture.md)
- End-to-end release wrapper: `./scripts/release_dmg.sh --skip-notarize`
- One-command local DMG build: `./scripts/build_dmg.sh`
- One-command notarize + staple: `./scripts/notarize_dmg.sh --keychain-profile "<profile>"`

## Release and Updates (Current)

- Distribution: GitHub Releases (signed + notarized DMG).
- In-app updater: Sparkle 2 (stable channel).
- Appcast URL: `https://parham-dev.github.io/mac-copilot/appcast.xml`
- Pages root URL: `https://parham-dev.github.io/mac-copilot/`

The `Update` button is currently manual-trigger only. It now shows immediate local feedback ("Checking for updates..."), then Sparkle handles the update UI if an update is available.

## Notes for Contributors

- Keep feature boundaries strict: avoid cross-feature concrete dependencies where possible.
- Put business models and contracts in `Domain`, implementations in `Data`, UI in `Presentation`.
- Prefer adding use cases for orchestration instead of embedding flow logic in views.
- Keep sidecar communication local-only (`127.0.0.1`).

## Security and Privacy

- Sidecar runs locally.
- Tokens are handled via app auth flow and local secure storage patterns.
- Do not commit secrets, tokens, or local env files.

## Roadmap (Short)

- Harden sidecar startup/health observability
- Expand project/runtime adapter coverage (framework-aware profiles)
- Improve runtime health strategy for custom app startup signatures
- Add deployment workflows and approvals
- Improve shell domain/use-case coverage

---

For historical planning notes, see `README_PHASE2.md`.
