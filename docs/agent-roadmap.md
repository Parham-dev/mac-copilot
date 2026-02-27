# Agent Roadmap (Workflow-First, No Catalog Yet)

Date: 2026-02-27

This roadmap is based on the current mac-copilot architecture:
- project-scoped chat runtime already exists
- model selection and Native tool allowlisting already exist
- sidecar prompt streaming (SSE) and tool execution traces already exist
- Apps/Skills direction is already documented

The goal is to ship **one high-value agent flow first** (URL Summarizer), then expand to more agents and skills support without adding a marketplace yet.

Important V1 runtime decision:
- Reuse the current Copilot prompt runtime core.
- Do **not** depend on the chat layer for agent persistence or UI.
- Keep streaming transport internally, but present a **final structured result** UI for agents.

---

## Agents

### URL Summariser (Placeholder)
- **Status:** Planned (V1 first built-in agent)
- **Purpose:** Summarise a webpage URL into structured, decision-ready output.
- **Primary input:** `url`
- **Optional inputs:** `goal`, `audience`, `tone`, `length`, `outputFormat`
- **Default tool scope:** `fetch_webpage` only (minimal and safe by default)
- **Output shape:** TL;DR, Key Points, Risks/Unknowns, Suggested Next Actions, Source Metadata

## 1) Current System Fit (What you already have)

### Existing strengths
1. **Prompt runtime with streaming output**
   - mac app sends prompt + model + projectPath + optional allowedTools.
   - sidecar streams events and tool execution updates.
2. **Tool control already in product**
   - Native tools can be enabled/disabled and persisted.
   - Prompt payload only sends `allowedTools` when narrowed (important SDK behavior).
3. **Session context model exists**
   - sidecar session manager keys sessions by chat/project context.
4. **History and persistence foundations exist**
   - user and assistant messages are persisted with metadata and tool traces.

### Gap to fill for agents
- No first-class `AgentDefinition` yet.
- No per-agent input schema/form layer.
- No per-agent run history model separate from chat timeline.
- No provider connection model (Replicate etc.) yet.
- No skill discovery/activation pipeline yet.

---

## 2) Product Strategy

### Start with one agent
Start with **URL Summarizer Agent** because it:
- provides immediate user value
- uses existing runtime + existing `fetch_webpage` tool
- avoids adding provider auth in first cut
- is ideal for proving the “non-technical workflow” UX

### Runtime stance for V1 agents
- Use existing `/prompt` SSE pipeline (already stable in app + sidecar).
- For agent UX, do not render token streaming as primary UI.
- Wait for completion, then render a structured result card/view.
- Keep optional internal diagnostics (status/tool events) for debug panel and telemetry.

### Do not build yet
- no public marketplace
- no full agent catalog browsing
- no multi-agent orchestration graph
- no auto-generated agents (v3)

---

## 3) MVP Scope (Agent V1)

## V1 user flow
1. Open Agent screen (single built-in agent only)
2. Fill structured inputs
3. Run
4. Show loading/progress state (not token-by-token transcript)
5. Save run in agent history
6. Render final structured result in rich SwiftUI sections

## URL Summarizer V1 input schema
Required:
- `url` (string)

Optional:
- `goal` (summary, key takeaways, action items, compare)
- `audience` (general, founder, engineer, marketer)
- `tone` (neutral, concise, executive)
- `length` (short, medium, long)
- `outputFormat` (bullet, markdown brief, table)

## URL Summarizer V1 output contract
Return sections in this order:
1. TL;DR
2. Key Points
3. Risks / Unknowns
4. Suggested Next Actions
5. Source Metadata (url, title if available, fetchedAt)

Machine contract (for UI rendering):
- Agent must return JSON matching a strict schema first.
- Optional display markdown can be generated from that JSON after validation.
- If schema parse fails, run is marked failed with recovery guidance.

---

## 4) Technical Architecture (Minimal additions)

## New domain models
1. `AgentDefinition`
   - id
   - name
   - description
   - allowedToolsDefault (URL agent: only web-fetch + minimal safe helpers)
   - inputSchema (dynamic form config)
   - outputTemplate (section contract)
   - requiredConnections (empty for URL v1)
   - optionalSkill
   - cunstom insuctions

2. `AgentRun`
   - id, agentID, projectID
   - inputPayload
   - status (queued, running, completed, failed, cancelled)
   - streamedOutput (optional debug only)
   - finalOutput
   - startedAt, completedAt
   - diagnostics (tool traces, warnings)

3. `AgentSkillRef`
   - name
   - description
   - location (filesystem path)
   - version (optional)

## Runtime mapping to existing system
- Keep one runtime path (`/prompt` SSE).
- Build prompt from structured agent inputs.
- Pass restricted tool list for agent execution (minimal set for each agent).
- Parse SSE events internally and accumulate text until completion.
- Validate final text as structured JSON payload.
- Persist result only to agent run store for V1 (no required chat linkage).

## What we reuse vs skip
Reuse:
- `CopilotAPIService` / `CopilotPromptRepository` / `SendPromptUseCase`
- sidecar `/prompt` route and session manager
- model selection + `allowedTools` behavior

Skip in V1 agent flow:
- `ChatSessionCoordinator` message append/update lifecycle
- chat transcript rendering and chat thread persistence

---

## 5) Skills Integration Plan (V1.5, after URL agent)

Based on Agent Skills docs (`llms.txt`, `integrate-skills`, `specification`):

## Required behavior
1. Discover skill folders containing `SKILL.md`
2. Parse frontmatter only at startup (`name`, `description`)
3. Inject available skill metadata into runtime context
4. Activate by loading full `SKILL.md` only when selected/relevant
5. Optionally load `references/`, `assets/`, `scripts/` on demand

## Recommended implementation style for this app
Use **tool-based integration** first:
- define internal tools for:
  - `list_skills`
  - `read_skill`
  - `read_skill_resource`
- avoid unrestricted filesystem shell usage for non-technical users

## Skill authoring constraints to enforce
- `SKILL.md` frontmatter required (`name`, `description`)
- validate `name` format and directory-name match
- keep main skill instructions concise (progressive disclosure)

---

## 6) Main Challenges and Edge Cases

## A) URL ingestion and fetch reliability
Challenges:
- invalid URLs
- redirects and timeout
- blocked bots / 403 / 429
- non-HTML content
- giant pages causing context overflow

Mitigations:
- strict URL validation (`http/https`, block local/private IPs)
- explicit fetch timeout + retry strategy
- content-type checks
- chunking and hierarchical summarize for long pages
- always store source metadata for traceability

## B) Prompt injection from web content
Challenges:
- pages can include hostile text like “ignore prior instructions”

Mitigations:
- hard system rule: page text is untrusted data
- separate extraction phase from synthesis phase
- never allow webpage text to alter tool permissions

## C) Tool permission drift
Challenges:
- wrong `allowedTools` payload can reduce model performance/behavior

Mitigations:
- preserve current behavior: send narrowed `allowedTools` only when truly restricted
- define per-agent default tool scopes and explicit overrides
- add logging for requested tool count per run

V1 URL agent tool scope recommendation:
- allow: `fetch_webpage`
- optional: one lightweight file/tool helper only if needed for output post-processing
- deny by default: terminal, patching, project mutation tools

## D) Non-technical UX failures
Challenges:
- users don’t understand “why this failed”

Mitigations:
- clear error copy mapped to common failure classes:
  - URL invalid
  - site blocked
  - timeout
  - no extractable content
- one-click retry with same inputs
- show “last successful fetch” metadata

## E) Skills security and trust
Challenges:
- scripts inside skills may execute unsafe actions

Mitigations:
- default to read-only skill usage first (instructions/references)
- explicit user confirmation before any script execution
- allowlist trusted skill roots
- audit log skill activation and script runs

---

## 7) Delivery Phases

## Phase A (1–2 weeks): URL Agent MVP
Deliver:
- single-agent screen (no catalog)
- dynamic form from hardcoded schema for URL agent
- run button + progress state + final structured result UI
- agent run history list (basic)
- robust error states for URL/fetch failures
- strict schema validation for final JSON result

Acceptance:
- user can run URL summarize repeatedly
- outputs are structured and reproducible
- failed runs produce actionable message

## Phase B (1 week): hardening + observability
Deliver:
- telemetry for run lifecycle
- retry/backoff improvements
- token-budget protections for long pages
- regression tests for tool allowlist behavior

Acceptance:
- stable behavior under slow/failing websites
- no regression in chat-mode tooling behavior

## Phase C (1–2 weeks): skills foundation (local only)
Deliver:
- local skill discovery and frontmatter parse
- metadata injection into runtime context
- optional skill attachment per agent
- validation on import (basic spec checks)

Acceptance:
- agent can discover/use selected skills reliably
- startup remains fast with many skills

## Phase D (later): agent packs + marketplace
Deliver later:
- share/import/export agent definitions
- provider connections (Replicate first)
- marketplace and team distribution

---

## 8) Data and API Contract Notes

## Keep existing prompt route
No immediate sidecar API break required.
Use existing `/prompt` payload and build a structured prompt envelope in app/runtime.

Agent execution mode on top of existing route:
- transport remains streaming (SSE)
- product UI mode is final-result-first
- stream events are consumed internally until `done`
- final payload is parsed into typed Swift model for rendering

## Suggested structured prompt envelope
- system: agent contract + output format + guardrails
- context: fetched webpage content + metadata + selected skill snippets
- user: form inputs

## Persistence strategy
- Add dedicated `AgentRun` persistence table/model
- No required chat linkage for V1
- Optional `chatID` field remains nullable for future compatibility

---

## 9) What to build next (immediate execution order)

1. Add `AgentDefinition` + one built-in URL agent definition.
2. Build single-agent run screen with dynamic form renderer.
3. Build `AgentExecutionService` that reuses prompt streaming repository without chat coordinator.
4. Implement URL fetch + sanitize + summarize pipeline with strict minimal tools.
5. Validate and persist typed final structured output (`AgentRunResult`).
6. Add error taxonomy and retry UX.
7. Add skills discovery skeleton (metadata only).

---

## 10) Decision log (recommended)

- Decision: no catalog in V1.
- Decision: URL Summarizer is first agent.
- Decision: keep one runtime path; don’t fork chat runtime.
- Decision: no chat persistence dependency for V1 agent runs.
- Decision: final structured output is primary UX; streaming is internal transport.
- Decision: URL Summarizer uses minimal tool scope (`fetch_webpage` first).
- Decision: skills support is local-first and read-mostly first.
- Decision: provider connections (Replicate) come after URL agent is stable.
