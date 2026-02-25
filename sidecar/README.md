# Sidecar (Node Runtime)

This folder contains the local Copilot sidecar used by the macOS app.

## Milestone Workflow

### Milestone 1 — TypeScript Scaffold
- Source files in `src/`
- Build output in `dist/`
- Legacy runtime entrypoint remains `index.js` during migration

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

## Doctor Output

`npm run doctor` validates:
- current Node version and executable path
- `node:sqlite` support
- `@github/copilot-sdk` presence in `node_modules`

It exits non-zero when runtime is not compatible.
