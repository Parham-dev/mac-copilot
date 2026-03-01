# Agent Tool Architecture Refactor (Proposed)

## Goal
Make tool behavior production-safe, per-agent configurable, and easy to change across app features.

## Current Strengths
- Session config already supports `availableTools`, `mcpServers`, `skillDirectories`, and `disabledSkills`.
- Hook layer already enforces pre/post tool policy and auditing.
- URL agent strict mode and MCP-first behavior are implemented.

## Refactor Plan
1. **Add Agent Execution Context**
   - Pass `agentID`, `feature`, and `policyProfile` into sidecar `/prompt` payload.
   - Attach this context to session hook decisions and logs.

2. **Centralize Tool Policy Registry**
   - Create one registry: `native`, `custom`, `mcp` tool classes.
   - Define per-agent policy profiles (allow/deny/strict fallback rules).

3. **Introduce Custom Tools Layer**
   - Register app-specific custom tools in `createSession`.
   - Expose custom tools without forcing hardcoded tool-order prompts.

4. **Agent-Aware Hooks**
   - Make `onPreToolUse` evaluate policy by `agentID` + tool class.
   - Return deterministic denial reasons and remediation hints.

5. **Observability Contract**
   - Emit standardized fields: `tool_class`, `policy_profile`, `decision`, `fallback_used`.
   - Add run-level summary: `tool_path=custom|mcp|native|none`.

6. **Packaging + Runtime Config**
   - Bundle `skills/` for release builds where required.
   - Keep env overrides for ops: strict mode, disabled skills, MCP command path.

## Suggested File Targets
- `sidecar/src/copilot/copilotSessionManager.ts`
- `sidecar/src/copilot/copilotSessionHooks.ts`
- `sidecar/src/promptRoute.ts`
- `mac-copilot/Features/Agents/Data/Execution/PromptAgentExecutionService.swift`

## Acceptance Criteria
- Per-agent tool policy is deterministic and testable.
- Tool class decisions are explicit and logged, while final tool-order choice remains model-driven.
- No silent fallback in strict policies.
- Skills can be enabled/disabled without code changes.
