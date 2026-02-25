# DMG Release Guide

This guide documents the recommended way to package and distribute CopilotForge as a DMG.

## End-to-End Script (Build + Optional Notarization)

Use one wrapper script for the full pipeline:

```bash
./scripts/release_dmg.sh --skip-notarize
```

Production mode:

```bash
./scripts/release_dmg.sh --keychain-profile "<profile>"
```

Useful options:

```bash
./scripts/release_dmg.sh --help
./scripts/release_dmg.sh --dmg-path "/path/to/mac-copilot.dmg" --skip-notarize
./scripts/release_dmg.sh --app-path "/path/to/mac-copilot.app" --keychain-profile "<profile>"
```

## Quick Local Build (One Command)

For local/internal testing, use:

```bash
./scripts/build_dmg.sh
```

Output:
- `dist/mac-copilot.dmg`

Useful options:

```bash
./scripts/build_dmg.sh --help
./scripts/build_dmg.sh --app-path "/path/to/mac-copilot.app"
./scripts/build_dmg.sh --output "/path/to/custom/mac-copilot.dmg"
```

## Quick Notarization (One Command)

After you have a signed app + DMG, use:

```bash
./scripts/notarize_dmg.sh --keychain-profile "<profile>"
```

Useful options:

```bash
./scripts/notarize_dmg.sh --help
./scripts/notarize_dmg.sh --keychain-profile "<profile>" --dmg-path "/path/to/mac-copilot.dmg"
./scripts/notarize_dmg.sh --keychain-profile "<profile>" --app-path "/path/to/mac-copilot.app"
./scripts/notarize_dmg.sh --keychain-profile "<profile>" --skip-app
```

## Prerequisites

- Apple Developer account with Developer ID certificates
- Xcode configured for signing
- `notarytool` keychain profile configured
- Build machine with compatible Node installed (or `COPILOTFORGE_NODE_PATH` set) so bundling can copy Node into app resources

## 1) Build and Archive

1. Open `mac-copilot.xcodeproj`.
2. Select the `mac-copilot` scheme and `Any Mac (Apple Silicon, Intel)` if available.
3. Set configuration to `Release`.
4. Run `Product > Archive`.

Expected result:
- Archive succeeds and the sidecar bundle phase copies:
  - bundled `node`
  - `sidecar/dist`
  - `sidecar/node_modules`

## 2) Export Signed App

From Organizer:
1. Select latest archive.
2. Click `Distribute App`.
3. Choose `Developer ID`.
4. Export signed `mac-copilot.app`.

## 3) Notarize and Staple App

```bash
xcrun notarytool submit "/path/to/mac-copilot.app" --keychain-profile "<profile>" --wait
xcrun stapler staple "/path/to/mac-copilot.app"
```

## 4) Build DMG

```bash
mkdir -p release
cp -R "/path/to/mac-copilot.app" release/
hdiutil create -volname "mac-copilot" -srcfolder release -ov -format UDZO mac-copilot.dmg
```

## 5) Notarize and Staple DMG

```bash
xcrun notarytool submit "mac-copilot.dmg" --keychain-profile "<profile>" --wait
xcrun stapler staple "mac-copilot.dmg"
```

## 6) Final Verification

- Install from DMG on a clean machine/user profile.
- Confirm app launches without Node installed system-wide.
- Confirm GitHub sign-in and first chat prompt work.
- Confirm sidecar health is green (`/health` reachable by app).
