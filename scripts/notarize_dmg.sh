#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

APP_PATH=""
DMG_PATH="$REPO_ROOT/dist/mac-copilot.dmg"
KEYCHAIN_PROFILE=""
SKIP_APP=0
SKIP_DMG=0

usage() {
  cat <<EOF
Usage: scripts/notarize_dmg.sh --keychain-profile <profile> [options]

Notarize and staple CopilotForge app + DMG.

Options:
  --keychain-profile <profile>  notarytool keychain profile name (required)
  --app-path <path>             Path to signed mac-copilot.app
  --dmg-path <path>             Path to DMG (default: dist/mac-copilot.dmg)
  --skip-app                    Skip app notarization/stapling
  --skip-dmg                    Skip DMG notarization/stapling
  -h, --help                    Show help

Notes:
  - The app should be signed before notarization.
  - If --app-path is not provided, this script tries to locate mac-copilot.app
    next to the DMG first, then in .build/dmg/staging.
EOF
}

log() {
  echo "[notarize_dmg] $1"
}

fail() {
  echo "[notarize_dmg] $1" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --keychain-profile)
      KEYCHAIN_PROFILE="${2:-}"
      shift 2
      ;;
    --app-path)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --dmg-path)
      DMG_PATH="${2:-}"
      shift 2
      ;;
    --skip-app)
      SKIP_APP=1
      shift
      ;;
    --skip-dmg)
      SKIP_DMG=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$KEYCHAIN_PROFILE" ]; then
  usage
  fail "Missing required --keychain-profile"
fi

if ! command -v xcrun >/dev/null 2>&1; then
  fail "xcrun not found. Install Xcode command line tools."
fi

if [ "$SKIP_APP" -eq 0 ] && [ -z "$APP_PATH" ]; then
  dmg_dir="$(dirname "$DMG_PATH")"
  candidate1="$dmg_dir/mac-copilot.app"
  candidate2="$REPO_ROOT/.build/dmg/staging/mac-copilot.app"

  if [ -d "$candidate1" ]; then
    APP_PATH="$candidate1"
  elif [ -d "$candidate2" ]; then
    APP_PATH="$candidate2"
  fi
fi

if [ "$SKIP_APP" -eq 0 ]; then
  [ -d "$APP_PATH" ] || fail "App bundle not found. Pass --app-path /path/to/mac-copilot.app"
  log "Submitting app for notarization: $APP_PATH"
  xcrun notarytool submit "$APP_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait

  log "Stapling app: $APP_PATH"
  xcrun stapler staple "$APP_PATH"
fi

if [ "$SKIP_DMG" -eq 0 ]; then
  [ -f "$DMG_PATH" ] || fail "DMG not found at $DMG_PATH"
  log "Submitting DMG for notarization: $DMG_PATH"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait

  log "Stapling DMG: $DMG_PATH"
  xcrun stapler staple "$DMG_PATH"
fi

log "Done"
