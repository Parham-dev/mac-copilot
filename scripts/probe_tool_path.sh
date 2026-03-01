#!/bin/sh
set -eu

BASE_URL="${COPILOTFORGE_BASE_URL:-http://127.0.0.1:7878}"
MODEL="${COPILOTFORGE_PROBE_MODEL:-gpt-5}"
TARGET_URL="${1:-https://example.com}"

STRICT_SSE="/tmp/copilotforge-probe-strict.sse"
DEFAULT_SSE="/tmp/copilotforge-probe-default.sse"

chat_id() {
  prefix="$1"
  printf "%s-%s-%s" "$prefix" "$(date +%s)" "$RANDOM"
}

run_probe() {
  profile="$1"
  output_file="$2"
  chat="$(chat_id "$profile")"

  payload=$(cat <<JSON
{"prompt":"Summarize this URL in 3 bullets: ${TARGET_URL}","chatID":"${chat}","model":"${MODEL}","allowedTools":["fetch","web_fetch","fetch_webpage"],"executionContext":{"agentID":"url-summariser","feature":"agents","policyProfile":"${profile}"}}
JSON
)

  curl -sN -X POST "${BASE_URL}/prompt" \
    -H "Content-Type: application/json" \
    --data "$payload" > "$output_file"
}

summarize_sse() {
  file="$1"

  tools=$(grep -o '"toolName":"[^"]*"' "$file" | sed 's/"toolName":"\([^"]*\)"/\1/' | sort -u | tr '\n' ' ')
  if [ -z "$tools" ]; then
    tool_path="none"
    fallback_used="false"
  else
    class_count=0
    tool_path="none"
    has_native=0
    has_mcp=0
    has_custom=0

    for tool in $tools; do
      normalized=$(printf "%s" "$tool" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')
      case "$normalized" in
        fetch|fetch_*)
          [ "$has_mcp" -eq 1 ] || class_count=$((class_count + 1))
          has_mcp=1
          [ "$tool_path" = "none" ] && tool_path="mcp"
          ;;
        copilotforge_*|app_*)
          [ "$has_custom" -eq 1 ] || class_count=$((class_count + 1))
          has_custom=1
          tool_path="custom"
          ;;
        *)
          [ "$has_native" -eq 1 ] || class_count=$((class_count + 1))
          has_native=1
          if [ "$tool_path" = "none" ]; then
            tool_path="native"
          fi
          ;;
      esac
    done

    if [ "$class_count" -gt 1 ]; then
      fallback_used="true"
    else
      fallback_used="false"
    fi
  fi

  denied_reason=""
  if grep -q 'strict Fetch MCP mode is enabled' "$file"; then
    denied_reason="strict_fetch_mcp_mode"
  fi

  printf "tool_names=%s\n" "${tools:-<none>}"
  printf "tool_path=%s\n" "$tool_path"
  printf "fallback_used=%s\n" "$fallback_used"
  if [ -n "$denied_reason" ]; then
    printf "deny_reason=%s\n" "$denied_reason"
  fi
}

echo "[probe] strict profile"
run_probe "strict-fetch-mcp" "$STRICT_SSE"
summarize_sse "$STRICT_SSE"
echo ""

echo "[probe] default profile"
run_probe "default" "$DEFAULT_SSE"
summarize_sse "$DEFAULT_SSE"
echo ""

echo "[probe] raw files"
echo "$STRICT_SSE"
echo "$DEFAULT_SSE"
