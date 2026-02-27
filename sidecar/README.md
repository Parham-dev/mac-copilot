# Sidecar (Node Runtime)

This folder contains the local Copilot sidecar used by the macOS app.

## Milestone Workflow

### Milestone 1 — TypeScript Scaffold
- Source files in `src/`
- Build output in `dist/`
- Runtime launches from `dist/index.js`

### Milestone 2 — Portability Hardening
- Runtime diagnostics endpoint: `GET /doctor`
- Node compatibility requirement: `node:sqlite` support (Node 22+)
- Sidecar startup prefers compatible runtime and avoids stale incompatible process reuse

### Milestone 3 — Packaging Validation
Use:

```bash
npm run check
```

This runs:
1. `npm run typecheck`
2. `npm run build`
3. `npm run doctor`

## Commands

```bash
npm install
npm run typecheck
npm run build
npm run doctor
npm run check
npm run start
npm run start:dist
```

## Runtime Notes (Small but Important)

- The app sidecar now runs from `dist/index.js`.
- Canonical source entry is `src/index.ts`.
- Copilot runtime logic lives under `src/copilot/` (for example `copilot.ts`, `copilotPromptStreaming.ts`, `copilotSessionManager.ts`).
- If you hit local runtime issues, run `npm run check` first.
- If an old sidecar is still bound to port `7878`, stop it and restart from `sidecar/`.

## Runtime Environment Flags

- `COPILOTFORGE_SKILL_DIRECTORIES` — comma-separated skill parent directories for SDK `skillDirectories` (example: `./skills,/opt/copilot/skills`).
- `COPILOTFORGE_DISABLED_SKILLS` — comma-separated skill names mapped to SDK `disabledSkills` (example: `experimental-feature,deprecated-tool`).
- `COPILOTFORGE_BACKGROUND_COMPACTION_THRESHOLD` — overrides infinite session `backgroundCompactionThreshold`.
- `COPILOTFORGE_BUFFER_EXHAUSTION_THRESHOLD` — overrides infinite session `bufferExhaustionThreshold`.
- `COPILOTFORGE_OTEL_ENABLED=1` — enables optional OpenTelemetry span emission for prompt/tool lifecycle.

## Release vs Debug Node Policy

- `Debug`: resolver prefers bundled Node but can fall back to compatible system Node for local development.
- `Release`: resolver is bundled-only (no system `PATH` fallback).
- Release packaging should copy these into app resources:
	- `node` executable
	- `sidecar/dist`
	- `sidecar/node_modules`

An Xcode build phase script can automate this copy step from the repository sidecar folder.

## Doctor Output

`npm run doctor` validates:
- current Node version and executable path
- `node:sqlite` support
- `@github/copilot-sdk` presence in `node_modules`

It exits non-zero when runtime is not compatible.
