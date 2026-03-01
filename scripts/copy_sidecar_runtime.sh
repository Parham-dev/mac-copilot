#!/bin/sh
set -eu

log() {
  echo "[CopilotForge][BuildPhase] $1"
}

fail_or_warn() {
  message="$1"
  if [ "${CONFIGURATION:-Debug}" = "Release" ]; then
    echo "error: $message"
    exit 1
  fi
  echo "warning: $message"
}

PROJECT_ROOT="${SRCROOT}"
SIDECAR_DIR="${PROJECT_ROOT}/sidecar"
RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

if [ ! -d "$SIDECAR_DIR" ]; then
  fail_or_warn "sidecar directory not found at $SIDECAR_DIR"
  exit 0
fi

mkdir -p "$RESOURCES_DIR/sidecar"

if [ -d "$SIDECAR_DIR/dist" ]; then
  mkdir -p "$RESOURCES_DIR/sidecar/dist"
  rsync -a --delete "$SIDECAR_DIR/dist/" "$RESOURCES_DIR/sidecar/dist/"
  log "Copied sidecar dist"
else
  fail_or_warn "sidecar dist not found. Run 'cd sidecar && npm run build'"
fi

if [ -d "$SIDECAR_DIR/node_modules" ]; then
  mkdir -p "$RESOURCES_DIR/sidecar/node_modules"
  rsync -a --delete --exclude ".cache" "$SIDECAR_DIR/node_modules/" "$RESOURCES_DIR/sidecar/node_modules/"
  log "Copied sidecar node_modules"
else
  fail_or_warn "sidecar node_modules not found. Run 'cd sidecar && npm install'"
fi

SKILLS_DIR="${PROJECT_ROOT}/skills"
if [ -d "$SKILLS_DIR" ]; then
  mkdir -p "$RESOURCES_DIR/skills"
  rsync -a --delete "$SKILLS_DIR/" "$RESOURCES_DIR/skills/"
  log "Copied skills"
else
  fail_or_warn "skills directory not found at $SKILLS_DIR"
fi

NODE_SOURCE=""

if [ -n "${COPILOTFORGE_NODE_PATH:-}" ] && [ -x "${COPILOTFORGE_NODE_PATH}" ]; then
  NODE_SOURCE="${COPILOTFORGE_NODE_PATH}"
elif command -v node >/dev/null 2>&1; then
  NODE_SOURCE="$(command -v node)"
fi

if [ -z "$NODE_SOURCE" ]; then
  fail_or_warn "No Node executable found for bundling. Set COPILOTFORGE_NODE_PATH or install Node 22+"
  exit 0
fi

if ! "$NODE_SOURCE" --input-type=module -e "await import('node:sqlite');" >/dev/null 2>&1; then
  fail_or_warn "Node at $NODE_SOURCE is incompatible (missing node:sqlite). Use Node 22+"
  exit 0
fi

if [ -e "$RESOURCES_DIR/node" ]; then
  chmod u+w "$RESOURCES_DIR/node" 2>/dev/null || true
  rm -f "$RESOURCES_DIR/node"
fi

cp "$NODE_SOURCE" "$RESOURCES_DIR/node"
chmod 755 "$RESOURCES_DIR/node"
log "Bundled Node from $NODE_SOURCE"
