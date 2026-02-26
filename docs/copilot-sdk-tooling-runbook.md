# Copilot SDK Tooling Runbook (Mac Copilot)

## Confirmed Findings
- `@github/copilot-sdk` message delivery modes are `"enqueue" | "immediate"`.
- Sending unsupported mode values causes unstable behavior and misleading debugging paths.
- The most impactful regression in this app was **always sending explicit `allowedTools`** from UI.
- When the user selected "all tools" (or no explicit narrowing), forwarding a full allowlist changed SDK behavior vs historical default.
- Restoring default behavior by sending `allowedTools = nil` (unless user truly narrows tools) resolved the issue.

## Working Rules
1. Keep stream flow simple (`session.send({ prompt, mode: "immediate" })`) unless a validated SDK reason exists.
2. Only send `allowedTools` when the user selected a strict subset.
3. If enabled set equals full catalog, treat as unrestricted (`nil`).
4. Prefer small diagnostics over behavioral guardrails that block requests.

## Quick Triage Checklist
- Verify request payload logs:
  - `requestedModel`
  - `requestedAllowedToolsCount`
- If tool behavior regresses:
  - Check whether `allowedTools` is non-null unexpectedly.
  - Re-test with unrestricted tools (`allowedTools = nil`).
- Confirm SDK compatibility:
  - Mode values are valid (`immediate`/`enqueue`).
  - Event names match SDK (`tool.execution_start`, `tool.execution_complete`, `session.error`, `session.idle`).

## Code Locations
- Prompt send flow from UI: `mac-copilot/Features/Chat/Presentation/ViewModel/ChatViewModel+SendFlow.swift`
- Sidecar prompt endpoint: `sidecar/src/index.ts`
- Sidecar stream handling: `sidecar/src/copilotPromptStreaming.ts`
- Sidecar SDK dispatch: `sidecar/src/copilot.ts`
