# Documentation

This folder contains operational and release documentation for CopilotForge.

## Start Here

- [DMG Release Guide](release-dmg.md)
- [Sidecar Runtime and Packaging](sidecar-runtime.md)
- [Chat Session History Architecture](chat-session-history.md)
- [Testing Plan Roadmap](testing-plan-roadmap.md)
- [Git Feature README & Roadmap](git-feature-roadmap.md)
- [iOS Companion Architecture](ios-companion-architecture.md)
- [iOS Companion AI Agent Build Brief](ios-companion-ai-agent-brief.md)
- [Companion Validation Smoke Test](companion-validation-smoke.md)
- [Troubleshooting](troubleshooting.md)
- End-to-end release wrapper: `./scripts/release_dmg.sh --skip-notarize` (or pass keychain profile for production)
- One-command local DMG: `./scripts/build_dmg.sh`
- One-command notarize + staple: `./scripts/notarize_dmg.sh --keychain-profile "<profile>"`

## Documentation Style (Recommended)

- Keep guides task-focused with prerequisites, steps, and expected results.
- Prefer reproducible command snippets.
- Update docs whenever runtime, build, or distribution behavior changes.
- Add a short "Why this exists" section for non-obvious scripts/settings.
