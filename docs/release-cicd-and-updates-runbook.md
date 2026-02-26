# Release, CI/CD, and App Update Runbook (No App Store)

This runbook defines the full production path for shipping `mac-copilot` outside the Mac App Store using GitHub Releases + DMG, with optional in-app auto-updates.

Use this as the source of truth from prerequisites to final release testing.

Current workflow implementation lives at:

- `.github/workflows/release-dmg.yml`

---

## 1) Goal and Distribution Model

### What we are doing

- Distribute signed + notarized `.dmg` builds via **GitHub Releases**.
- Keep releases tag-based (`vX.Y.Z`) and reproducible.
- Maintain a stable release channel and optional beta channel.

### Why this model

- Faster than App Store review cycles.
- Full control over release cadence and rollback.
- Works well for developer tools and companion desktop apps.

---

## 2) Prerequisites (One-Time Setup)

## Apple + Signing

- Apple Developer Program membership.
- Developer ID Application certificate installed on a secure machine.
- Hardened Runtime enabled for release builds.
- `notarytool` profile configured (App Store Connect API key or Apple ID method).

## Repository + Access

- GitHub repository with Releases enabled.
- Maintainers with permission to create tags/releases.
- Branch protection on `main` (recommended).

## Local Tooling

- Xcode + command line tools.
- `xcrun notarytool` and `xcrun stapler` available.
- Existing scripts already in repo:
  - `scripts/build_dmg.sh`
  - `scripts/notarize_dmg.sh`
  - `scripts/release_dmg.sh`

## Secrets to prepare for CI

Add these in GitHub repository secrets:

- `MACOS_CERT_BASE64` (Developer ID cert in `.p12`, base64-encoded)
- `MACOS_CERT_PASSWORD`
- `KEYCHAIN_PASSWORD` (temporary CI keychain)
- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_ISSUER_ID`
- `APPLE_NOTARY_PRIVATE_KEY_BASE64` (base64 for `.p8`)
- (Optional) `APPCAST_SIGNING_PRIVATE_KEY` (if enabling Sparkle updates)

---

## 3) Versioning and Release Rules

- Use semantic versioning: `MAJOR.MINOR.PATCH`.
- Create releases only from tagged commits.
- Tag format: `vX.Y.Z` (example: `v1.4.2`).
- Never re-use a tag after publishing.

Recommended release policy:

- `PATCH`: bug fixes only.
- `MINOR`: features, backward-compatible.
- `MAJOR`: breaking behavior or migration.

---

## 4) CI/CD Workflow Design (GitHub Actions)

## Trigger

- On push of tags matching `v*`.
- Manual test trigger via `workflow_dispatch` (supports `skip_notarize=true` for dry-run validation).

## Pipeline stages (in order)

1. **Checkout + toolchain setup**
2. **Import signing certificate to temporary keychain**
3. **Install + build sidecar dependencies** (`cd sidecar && npm ci && npm run build`)
4. **Build Release app**
5. **Package DMG**
6. **Notarize app and DMG** (skipped in dry-run mode)
6. **Staple notarization ticket**
7. **Verify codesign + stapling**
8. **Generate SHA256 checksums**
9. **Create GitHub Release and upload assets**

## Required output assets

- `mac-copilot-<version>.dmg`
- `SHA256SUMS.txt`
- (Optional) `mac-copilot-<version>.zip` for alternative installers

## Failure policy

- If notarization fails: fail workflow and do not publish release.
- If signing validation fails: fail workflow and do not publish release.

---

## 5) Manual Pre-Release Checklist (Before Tagging)

- Ensure `main` is green.
- Confirm version/bundle metadata is updated in Xcode project.
- Verify sidecar runtime packaging is current.
- Verify sidecar lockfile/dependencies are committed and reproducible.
- Run targeted tests (at minimum critical integration tests).
- Confirm release notes draft includes user-facing changes and known issues.

Suggested command baseline:

```bash
xcodebuild -project mac-copilot.xcodeproj -scheme mac-copilot -destination 'platform=macOS' test
```

---

## 6) Release Execution (Operator Steps)

1. Merge release-ready PR into `main`.
2. Create and push tag:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

3. Watch GitHub Actions run to completion.
4. Validate generated release assets.
5. Publish GitHub Release notes.

### Safe validation flow before first production tag

1. Run CI dry-run (no notarization):

```bash
gh workflow run release-dmg.yml --ref main -f skip_notarize=true
```

2. Monitor run:

```bash
gh run list --workflow release-dmg.yml --limit 1
gh run watch
```

3. After dry-run succeeds, run normal tag release (`vX.Y.Z`) to execute notarization + release publishing.

---

## 7) App Update Strategy (Best Practice)

For non-App-Store macOS apps, recommended update path is **Sparkle 2**.

## Recommended update model

- Stable appcast feed for production users.
- Optional beta appcast for early adopters.
- Delta updates enabled where practical.
- Signature verification required for all updates.

## Hosting

- Host appcast + release artifacts on GitHub Releases.
- Serve appcast XML from GitHub Pages or your website.

## User experience

- Background update check (for example daily).
- Prompt user to install updates (or auto-download then prompt).
- Mandatory update messaging only for critical security fixes.

## Security requirements

- Sign updates with Sparkle private key.
- Keep signing keys separate from developer machine credentials.
- Rotate/revoke keys if compromise is suspected.

---

## 8) Final Release Validation (After CI Publishes)

Run this on a clean macOS user profile or clean machine.

## Installer and launch

- Download `.dmg` from GitHub Release.
- Verify checksum matches `SHA256SUMS.txt`.
- Install app from DMG to Applications.
- Launch succeeds without security warnings beyond normal first-open flow.

## Functional smoke test

- App boots and sidecar starts/reuses successfully.
- Sign-in/auth flow works.
- Create project/chat, send first prompt, receive response.
- Delete chat/project flows behave correctly.

## Runtime + packaging checks

- Confirm bundled runtime works without system Node dependency.
- Confirm sidecar health endpoint and model list load correctly.

## Update check (if Sparkle enabled)

- App can reach appcast.
- Update prompt appears for newer test version.
- Download + install update succeeds.
- Updated app launches and retains expected user data.

---

## 9) Rollback Plan

If a bad release is published:

1. Mark release as deprecated in notes.
2. Keep previous stable release visible and recommended.
3. Publish hotfix as next patch tag (`vX.Y.(Z+1)`)—do not overwrite old tag.
4. If Sparkle is enabled, repoint appcast to the known-good version.

---

## 10) Ongoing Maintenance

- Rotate signing/notary credentials periodically.
- Review CI logs for notarization latency/failure patterns.
- Keep DMG/release scripts current as Apple tooling evolves.
- Review release checklist quarterly.
- Keep this runbook updated whenever release flow changes.

---

## 11) CI Troubleshooting (What We Hit and Fixed)

### A) Workflow parse failure on dispatch

Symptom:

- GitHub workflow parser rejects `${{ runner.temp }}` in job-level `env`.

Fix:

- Use `$RUNNER_TEMP` inside step shell scripts instead of job-level expression references.

### B) Xcode project format mismatch on runner

Symptom:

- `xcodebuild: ... project file format (77) ... future Xcode format`.

Fix:

- Use a newer runner image (`macos-15`) with newer Xcode.

### C) Deployment target incompatibility on runner

Symptom:

- Build warns/fails because repo deployment target exceeds runner SDK support.

Fix:

- Override CI build target with `MACOSX_DEPLOYMENT_TARGET=15.5` in the workflow build step.

### D) Swift strict actor-isolation compile failures in Release

Symptom:

- `main actor-isolated property/method ... in nonisolated context` errors (exit 65).

Fix applied in source:

- `ShellNavigationHeaderState` marked `@MainActor`.
- `SignOutUseCase.execute()` marked `@MainActor`.

### E) Sidecar packaging script failure (`node_modules` missing)

Symptom:

- Build phase fails: `sidecar node_modules not found. Run 'cd sidecar && npm install'`.

Fix:

- Add CI step to install/build sidecar before `xcodebuild`.

---

## 12) Quick Commands Reference

Local DMG build:

```bash
./scripts/build_dmg.sh
```

Notarize existing artifacts:

```bash
./scripts/notarize_dmg.sh --keychain-profile "<profile>"
```

End-to-end wrapper:

```bash
./scripts/release_dmg.sh --keychain-profile "<profile>"
```
