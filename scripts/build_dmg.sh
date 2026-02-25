#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

APP_NAME="mac-copilot"
SCHEME="mac-copilot"
PROJECT_PATH="$REPO_ROOT/mac-copilot.xcodeproj"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$REPO_ROOT/.build/dmg/DerivedData"
STAGING_PATH="$REPO_ROOT/.build/dmg/staging"
OUTPUT_DIR="$REPO_ROOT/dist"
OUTPUT_DMG="$OUTPUT_DIR/mac-copilot.dmg"
APP_PATH=""
SKIP_BUILD=0

usage() {
  cat <<EOF
Usage: scripts/build_dmg.sh [options]

Build a local DMG for macOS distribution.

Options:
  --app-path <path>   Use an existing .app bundle instead of building.
  --output <path>     Output DMG path (default: dist/mac-copilot.dmg)
  --skip-build        Skip xcodebuild and package existing app from DerivedData.
  -h, --help          Show help.
EOF
}

log() {
  echo "[build_dmg] $1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app-path)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DMG="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
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

if [ -z "$APP_PATH" ]; then
  APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
fi

if [ "$SKIP_BUILD" -eq 0 ] && [ ! -d "$APP_PATH" ]; then
  log "Building $APP_NAME ($CONFIGURATION) with xcodebuild"
  mkdir -p "$DERIVED_DATA_PATH"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination 'platform=macOS' \
    build
fi

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found at: $APP_PATH" >&2
  echo "Run without --skip-build, or pass --app-path to a valid .app bundle." >&2
  exit 1
fi

mkdir -p "$STAGING_PATH" "$OUTPUT_DIR"
rm -rf "$STAGING_PATH/$APP_NAME.app"
cp -R "$APP_PATH" "$STAGING_PATH/$APP_NAME.app"

mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -f "$OUTPUT_DMG"

log "Creating DMG at $OUTPUT_DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_PATH" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG"

log "Done: $OUTPUT_DMG"
