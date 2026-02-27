# Copilot SDK Official Best-Practices Review (docs-gco)

This review compares current `mac-copilot` implementation against official guidance under `docs-gco/`.

## Reviewed Official Docs

All files under `docs-gco/` were reviewed, including:
- auth (`auth/index.md`, `auth/byok.md`)
- setup guides (`guides/setup/*`)
- session persistence (`guides/session-persistence.md`)
- hooks (`hooks/*`)
- MCP (`mcp/*`)
- compatibility/debugging/getting started
- OpenTelemetry instrumentation

## Current Code Areas Reviewed

- `sidecar/src/copilot/copilot.ts`
- `sidecar/src/copilot/copilotSessionManager.ts`
- `sidecar/src/copilot/copilotPromptStreaming.ts`
- `sidecar/src/promptRoute.ts`
- `mac-copilot/Features/Chat/Data/CopilotAPIService.swift`
- `mac-copilot/Features/Chat/Data/CopilotPromptStreamClient.swift`
- `mac-copilot/Features/Chat/Presentation/ViewModel/ChatViewModel+SendFlow.swift`

## Findings

### 1) Permission model is too permissive for production

- Official guidance: SDK is deny-by-default and expects explicit permission handling (`docs-gco/compatibility.md`, `docs-gco/hooks/pre-tool-use.md`).
- Current code: `onPermissionRequest: approveAll` in `sidecar/src/copilot/copilotSessionManager.ts`.
- Impact: all file/network/shell requests are approved without policy checks.
- Recommendation:
  - Replace blanket `approveAll` with an explicit policy handler.
  - Allow only required capabilities/paths and deny everything else.
  - Add logging and user-visible reason for denied actions.

### 2) Missing session hooks for policy, lifecycle, and error handling

- Official guidance: use hooks (`onPreToolUse`, `onPostToolUse`, `onUserPromptSubmitted`, `onSessionStart`, `onSessionEnd`, `onErrorOccurred`) for production controls (`docs-gco/hooks/overview.md`).
- Current code: no `hooks` object configured on session creation/resume.
- Impact: no centralized filtering/redaction/lifecycle metrics/recovery context.
- Recommendation:
  - Add a hooks module in sidecar and attach it in session config.
  - Start with:
    - pre-tool allow/deny + argument validation
    - post-tool redaction/truncation
    - onErrorOccurred telemetry

### 3) Missing token-usage event capture

- Official guidance: subscribe to `assistant.usage` for token telemetry (`docs-gco/compatibility.md`).
- Current code: prompt streaming subscribes to text/tool/idle events only.
- Impact: no usage metrics for cost/perf tracking.
- Recommendation:
  - Subscribe to `assistant.usage` in `copilotPromptStreaming.ts`.
  - Emit SSE usage events and optionally persist to metrics logs.

### 4) Infinite sessions enabled but thresholds are implicit

- Official guidance: configure compaction thresholds explicitly when using infinite sessions (`docs-gco/compatibility.md`, `docs-gco/guides/session-persistence.md`).
- Current code: `infiniteSessions: { enabled: true }`.
- Impact: behavior depends on SDK defaults and may vary across versions.
- Recommendation:
  - Set explicit `backgroundCompactionThreshold` and `bufferExhaustionThreshold`.
  - Document selected values in repo runbook.

### 5) Skill loading not wired into runtime session config

- Official guidance: `skillDirectories`/`disabledSkills` in `SessionConfig` when you want runtime skills (`docs-gco/guides/skills.md`).
- Current code: no runtime skill directory configuration in sidecar session config.
- Impact: app behavior does not benefit from SDK-level skill loading.
- Recommendation:
  - If intended product behavior includes SDK skills, add `skillDirectories` configuration.
  - Keep optional behind env/config flag if not always needed.

### 6) Observability can be upgraded to OpenTelemetry spans

- Official guidance: map session and tool events to OTel GenAI spans (`docs-gco/opentelemetry-instrumentation.md`).
- Current code: detailed logs exist, but no OTel spans.
- Impact: limited distributed tracing and cross-service correlation.
- Recommendation:
  - Add optional OTel instrumentation in sidecar:
    - parent span for each prompt request
    - child spans for tool execution
    - error attributes and finish reasons

## What Already Aligns Well

- Deterministic session IDs and resume-first flow per chat thread are aligned with session persistence best practices.
- `availableTools` is omitted (`nil`) when unrestricted, matching your runbook and avoiding unintended narrowing.
- Streaming event handling and `mode: "immediate"` are consistent with documented SDK event-driven patterns.

## Priority Order (Implementation)

`approveAll` replacement is intentionally deferred for now.

1. Add hooks (`pre/post/error/session lifecycle`) with basic policy + telemetry.
2. Set explicit `infiniteSessions` thresholds.
3. Add `assistant.usage` event handling.
4. Add optional OTel instrumentation.
5. Add optional `skillDirectories` runtime config if desired product behavior.
6. Replace `approveAll` with explicit permission policy (deferred hardening step).

Rationale: centralize governance hooks first, stabilize long-session behavior, add observability depth, and then complete least-privilege hardening.

## Implementation Constraints (Clean + Production-Ready)

- Keep each new or heavily modified source file under ~300 lines where practical; split policy, hooks, telemetry, and config into focused modules.
- Preserve sidecar boundaries: session creation/config in session manager, streaming in prompt streaming, HTTP translation in route layer.
- Prefer explicit config flags and defaults for production behavior; avoid implicit SDK defaults for security-sensitive or lifecycle-critical behavior.
- Add structured logging for allow/deny decisions and hook errors without leaking sensitive prompt/tool arguments.
- Keep changes incremental and testable: one concern per PR-sized change (permission policy, hooks, usage events, thresholds, OTel, skills).

## Suggested Validation After Changes

- Prompt execution with explicitly allowed and denied tool actions.
- Ensure denied actions produce deterministic user-facing output and machine-readable logs.
- Verify pre/post/lifecycle/error hooks fire with expected payload shape.
- Verify usage events are emitted over SSE and captured in logs/metrics.
- Run long chats and confirm explicit compaction thresholds behave as expected.
- Confirm no regression in existing text/tool streaming UX.
