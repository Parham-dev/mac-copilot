#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

BUILD_SCRIPT="$REPO_ROOT/scripts/build_dmg.sh"
NOTARIZE_SCRIPT="$REPO_ROOT/scripts/notarize_dmg.sh"

APP_PATH=""
DMG_PATH="$REPO_ROOT/dist/mac-copilot.dmg"
KEYCHAIN_PROFILE=""
SKIP_BUILD=0
SKIP_NOTARIZE=0

usage() {
  cat <<EOF
Usage: scripts/release_dmg.sh [options]

Build DMG and optionally notarize+staple.

Options:
  --keychain-profile <profile>  notarytool keychain profile (required unless --skip-notarize)
  --app-path <path>             Existing .app path for build/notarization flow
  --dmg-path <path>             DMG output/input path (default: dist/mac-copilot.dmg)
  --skip-build                  Skip xcodebuild and package existing app from DerivedData/app-path
  --skip-notarize               Build DMG only (local test mode)
  -h, --help                    Show help

Examples:
  ./scripts/release_dmg.sh --skip-notarize
  ./scripts/release_dmg.sh --keychain-profile "my-notary"
EOF
}

log() {
  echo "[release_dmg] $1"
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
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
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

[ -x "$BUILD_SCRIPT" ] || {
  echo "build script not executable: $BUILD_SCRIPT" >&2
  exit 1
}

build_args="--output \"$DMG_PATH\""
if [ -n "$APP_PATH" ]; then
  build_args="$build_args --app-path \"$APP_PATH\""
fi
if [ "$SKIP_BUILD" -eq 1 ]; then
  build_args="$build_args --skip-build"
fi

log "Running DMG build"
# shellcheck disable=SC2086
sh -c "\"$BUILD_SCRIPT\" $build_args"

if [ "$SKIP_NOTARIZE" -eq 1 ]; then
  log "Skipping notarization (--skip-notarize). DMG ready at: $DMG_PATH"
  exit 0
fi

if [ -z "$KEYCHAIN_PROFILE" ]; then
  echo "Missing --keychain-profile (or use --skip-notarize for local test mode)." >&2
  exit 1
fi

[ -x "$NOTARIZE_SCRIPT" ] || {
  echo "notarize script not executable: $NOTARIZE_SCRIPT" >&2
  exit 1
}

notary_args="--keychain-profile \"$KEYCHAIN_PROFILE\" --dmg-path \"$DMG_PATH\""
if [ -n "$APP_PATH" ]; then
  notary_args="$notary_args --app-path \"$APP_PATH\""
fi

log "Running notarization + stapling"
# shellcheck disable=SC2086
sh -c "\"$NOTARIZE_SCRIPT\" $notary_args"

log "Release pipeline complete"
