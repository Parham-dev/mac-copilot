# CopilotForge

CopilotForge is a native macOS app that provides a project-first chat workspace powered by GitHub Copilot.

- Native SwiftUI desktop shell
- Local Node sidecar for Copilot SDK integration
- Feature-first architecture (`Domain` / `Data` / `Presentation`)
- Local-first project and chat persistence

## Current Status

- Auth flow: implemented (GitHub device flow)
- Chat streaming: implemented
- Project-scoped workspace shell: implemented
- Preview runtime scaffolding: implemented
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

## Runtime Components

1. macOS app starts and initializes feature environment.
2. Sidecar lifecycle manager ensures local sidecar is healthy.
3. Swift app talks to sidecar on `127.0.0.1:7878`.
4. Sidecar executes Copilot SDK operations and streams responses.

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

3) Open the project

```bash
open mac-copilot.xcodeproj
```

4) Run the macOS app target from Xcode

## Documentation

- Operational and release docs: [docs/README.md](docs/README.md)
- End-to-end release wrapper: `./scripts/release_dmg.sh --skip-notarize`
- One-command local DMG build: `./scripts/build_dmg.sh`
- One-command notarize + staple: `./scripts/notarize_dmg.sh --keychain-profile "<profile>"`

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
- Expand project runtime preview adapters
- Add deployment workflows and approvals
- Improve shell domain/use-case coverage

---

For historical planning notes, see `README_PHASE2.md`.