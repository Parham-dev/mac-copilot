# Update Button Verification Guide

This guide verifies the `Update` button behavior end-to-end for production builds.

## Preconditions

- `appcast.xml` is live at:
  - `https://parham-dev.github.io/mac-copilot/appcast.xml`
- You have at least two published releases:
  - older installed build (for example `v1.0.7`)
  - newer available build (for example `v1.0.9`)

## What "working" looks like

When clicking `Update` in the app sidebar:

1. You immediately see a temporary banner: `Checking for updates...`
2. If a newer version exists, Sparkle presents update UI.
3. If no update exists, Sparkle may show no-op/no-update UI depending on current state.
4. If updater config is missing, a warning message is shown.

## Test Flow

1. Install an older release from GitHub Releases (DMG) into `/Applications`.
2. Launch the installed app (not Xcode debug run).
3. Click sidebar `Update`.
4. Confirm temporary `Checking for updates...` banner appears.
5. Confirm Sparkle finds newer version and prompts install.
6. Install update and relaunch.
7. Confirm app version changed to the newer release.

## Quick Troubleshooting

- Pressing `Update` shows banner but no Sparkle dialog:
  - Verify installed app is older than latest appcast item.
  - Verify app can access `https://parham-dev.github.io/mac-copilot/appcast.xml`.

- Error says missing `SUFeedURL` or `SUPublicEDKey`:
  - This usually means a local/Xcode run without release updater settings.
  - Validate using the notarized DMG-installed app.

- Sparkle cannot install update:
  - Check release artifact exists and URL in `appcast.xml` points to correct GitHub release DMG.
