# Documentation

This folder contains operational and release documentation for CopilotForge.

## Start Here

- [DMG Release Guide](release-dmg.md)
- [Sidecar Runtime and Packaging](sidecar-runtime.md)
- [Chat Session History Architecture](chat-session-history.md)
- [Troubleshooting](troubleshooting.md)
- End-to-end release wrapper: `./scripts/release_dmg.sh --skip-notarize` (or pass keychain profile for production)
- One-command local DMG: `./scripts/build_dmg.sh`
- One-command notarize + staple: `./scripts/notarize_dmg.sh --keychain-profile "<profile>"`

## Documentation Style (Recommended)

- Keep guides task-focused with prerequisites, steps, and expected results.
- Prefer reproducible command snippets.
- Update docs whenever runtime, build, or distribution behavior changes.
- Add a short "Why this exists" section for non-obvious scripts/settings.
