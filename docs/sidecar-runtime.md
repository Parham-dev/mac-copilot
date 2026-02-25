# Sidecar Runtime and Packaging

This guide explains how sidecar runtime resolution works across Debug and Release builds.

## Runtime Policy

- Debug builds:
  - Prefer bundled Node
  - Allow fallback to compatible system Node for development convenience
- Release builds:
  - Bundled Node only (no PATH fallback)
  - Fails fast if bundled runtime is missing or incompatible

## Why this policy exists

- Makes local development flexible.
- Makes shipped builds deterministic across user machines.
- Prevents runtime drift from stale/older system Node binaries.

## Bundled Layout Expected in App Resources

- `Contents/Resources/node`
- `Contents/Resources/sidecar/dist/index.js`
- `Contents/Resources/sidecar/node_modules/...`

## Build-Phase Script

The app target runs:
- `scripts/copy_sidecar_runtime.sh`

It:
1. Copies sidecar `dist` into app resources.
2. Copies sidecar `node_modules` into app resources.
3. Copies a compatible Node executable into app resources as `node`.
4. Enforces stricter behavior on `Release` builds (errors for missing requirements).

## Notes

- If script sandboxing blocks file operations, disable user script sandboxing for the app target build config.
- Keep `sidecar/dist` up to date (`npm run build`) when changing sidecar TypeScript code.
