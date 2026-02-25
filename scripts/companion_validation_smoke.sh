#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:7878}"
TTL_SECONDS="${TTL_SECONDS:-120}"
DEVICE_NAME="${DEVICE_NAME:-Smoke Test iPhone}"
DEVICE_PUBLIC_KEY="${DEVICE_PUBLIC_KEY:-smoke-public-key}"
DISCONNECT_AT_END="${DISCONNECT_AT_END:-1}"

pass_count=0
warn_count=0

log_pass() {
  pass_count=$((pass_count + 1))
  echo "✅ $1"
}

log_warn() {
  warn_count=$((warn_count + 1))
  echo "⚠️  $1"
}

log_info() {
  echo "ℹ️  $1"
}

require_json_ok() {
  local payload="$1"
  local context="$2"

  local ok
  ok="$(echo "$payload" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j.ok===true));}catch{process.stdout.write("false");}});')"
  if [[ "$ok" != "true" ]]; then
    echo "❌ ${context} failed"
    echo "$payload"
    exit 1
  fi
}

http_json() {
  local method="$1"
  local endpoint="$2"
  local body="${3:-}"

  local url="${BASE_URL}${endpoint}"
  local response

  if [[ -n "$body" ]]; then
    response="$(curl -sS -X "$method" "$url" -H 'content-type: application/json' --data "$body")"
  else
    response="$(curl -sS -X "$method" "$url")"
  fi

  echo "$response"
}

http_json_with_status() {
  local method="$1"
  local endpoint="$2"
  local body="${3:-}"

  local url="${BASE_URL}${endpoint}"
  local tmp
  tmp="$(mktemp)"
  local code

  if [[ -n "$body" ]]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$url" -H 'content-type: application/json' --data "$body")"
  else
    code="$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$url")"
  fi

  local payload
  payload="$(cat "$tmp")"
  rm -f "$tmp"

  printf '%s\n%s' "$code" "$payload"
}

disconnect_if_requested() {
  if [[ "$DISCONNECT_AT_END" != "1" ]]; then
    return
  fi

  if curl -sS -f "${BASE_URL}/health" >/dev/null 2>&1; then
    http_json POST "/companion/disconnect" >/dev/null || true
  fi
}

trap disconnect_if_requested EXIT

log_info "Using sidecar base URL: ${BASE_URL}"

health="$(http_json GET "/health")"
require_json_ok "$health" "Health check"
log_pass "Health endpoint reachable"

status_before="$(http_json GET "/companion/status")"
require_json_ok "$status_before" "Initial companion status"
log_pass "Companion status endpoint reachable"

pair_start="$(http_json POST "/companion/pairing/start" "{\"ttlSeconds\":${TTL_SECONDS}}")"
require_json_ok "$pair_start" "Pairing start"

pairing_code="$(echo "$pair_start" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j.code??""));}catch{}});')"
pairing_token="$(echo "$pair_start" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);const payload=JSON.parse(String(j.qrPayload??"{}"));process.stdout.write(String(payload.token??""));}catch{process.stdout.write("");}});')"

if [[ -z "$pairing_code" ]]; then
  echo "❌ Pairing start did not return a code"
  echo "$pair_start"
  exit 1
fi

log_pass "Pairing start returned code ${pairing_code}"

complete_body="$(cat <<JSON
{"pairingCode":"${pairing_code}","pairingToken":"${pairing_token}","deviceName":"${DEVICE_NAME}","devicePublicKey":"${DEVICE_PUBLIC_KEY}"}
JSON
)"

pair_complete="$(http_json POST "/companion/pairing/complete" "$complete_body")"
require_json_ok "$pair_complete" "Pairing complete"

connected="$(echo "$pair_complete" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j.connected===true));}catch{process.stdout.write("false");}});')"
if [[ "$connected" != "true" ]]; then
  echo "❌ Pairing complete did not connect"
  echo "$pair_complete"
  exit 1
fi
log_pass "Pairing completed and device connected"

status_after="$(http_json GET "/companion/status")"
require_json_ok "$status_after" "Post-pair status"
log_pass "Connected status available"

devices="$(http_json GET "/companion/devices")"
require_json_ok "$devices" "Devices list"

device_count="$(echo "$devices" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(Array.isArray(j.devices)?j.devices.length:0));}catch{process.stdout.write("0");}});')"
if [[ "$device_count" -lt 1 ]]; then
  echo "❌ Expected at least one trusted device after pairing"
  echo "$devices"
  exit 1
fi
log_pass "Trusted devices endpoint returned ${device_count} device(s)"

projects_status_and_payload="$(http_json_with_status GET "/companion/projects")"
projects_status="$(echo "$projects_status_and_payload" | head -n1)"
projects_payload="$(echo "$projects_status_and_payload" | tail -n +2)"

if [[ "$projects_status" == "200" ]]; then
  require_json_ok "$projects_payload" "Projects list"
  project_count="$(echo "$projects_payload" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(Array.isArray(j.projects)?j.projects.length:0));}catch{process.stdout.write("0");}});')"
  log_pass "Projects endpoint authorized (${project_count} project(s))"

  if [[ "$project_count" -gt 0 ]]; then
    first_project_id="$(echo "$projects_payload" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j.projects?.[0]?.id??""));}catch{}});')"

    chats="$(http_json GET "/companion/projects/${first_project_id}/chats")"
    require_json_ok "$chats" "Chats list"
    chat_count="$(echo "$chats" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(Array.isArray(j.chats)?j.chats.length:0));}catch{process.stdout.write("0");}});')"
    log_pass "Chats endpoint authorized (${chat_count} chat(s) in first project)"

    if [[ "$chat_count" -gt 0 ]]; then
      first_chat_id="$(echo "$chats" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j.chats?.[0]?.id??""));}catch{}});')"
      messages="$(http_json GET "/companion/chats/${first_chat_id}/messages?cursor=0&limit=20")"
      require_json_ok "$messages" "Messages page"
      message_count="$(echo "$messages" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(Array.isArray(j.messages)?j.messages.length:0));}catch{process.stdout.write("0");}});')"
      log_pass "Messages endpoint authorized (${message_count} message(s) in first chat)"
    else
      log_warn "No chats found; skipped messages endpoint check"
    fi
  else
    log_warn "No projects found; skipped chats/messages endpoint checks"
  fi
elif [[ "$projects_status" == "401" ]]; then
  log_warn "Projects endpoint returned 401 (expected when Mac is not Copilot-authenticated)"
elif [[ "$projects_status" == "403" ]]; then
  log_warn "Projects endpoint returned 403 (expected when companion connection guard blocks access)"
else
  echo "❌ Unexpected status from /companion/projects: ${projects_status}"
  echo "$projects_payload"
  exit 1
fi

echo
log_info "Smoke test complete: ${pass_count} passed, ${warn_count} warning(s)"
if [[ "$DISCONNECT_AT_END" == "1" ]]; then
  log_info "Device was disconnected at script exit (DISCONNECT_AT_END=1)"
fi
