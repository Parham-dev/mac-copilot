# Testing Plan Roadmap

## Why now

CopilotForge just completed a stabilization and refactor cycle. This is the right time to lock behavior with tests before adding more product surface.

## Test pyramid target

- Unit tests: 70%
- Integration tests: 20%
- UI and E2E tests: 10%

## Current testability assessment

Mostly testable today:
- Domain use cases and parsing logic are already easy to test.
- Several services and managers are close to testable but need DI seams.
- View behavior is testable at ViewModel and snapshot-style levels; full UI flow coverage is still thin.

Gaps to fix first:
- Sidecar lifecycle internals are concrete and time/process dependent.
- Some network clients still rely on concrete URLSession usage patterns.
- Git manager still executes real process commands directly.

## Test doubles strategy (what to use where)

- Fake: in-memory repositories and stores for fast deterministic flows.
- Stub: fixed outputs for model list, sidecar health, git status, profile payloads.
- Spy: verify calls, parameters, and call count for lifecycle and repository orchestration.
- Mock: only for strict interaction sequencing tests (restart/retry sequences).

Rule: prefer fake and stub first, then spy, then mock.

## Phase 0 (required): Testability refactor

Goal: add minimum seams so critical behavior can be tested without flaky process or UI timing.

Scope:
1. Sidecar lifecycle DI seams
   - Extract protocols for preflight, runtime utilities, process controller, restart policy clock/sleeper.
   - Inject these into SidecarManager via initializer defaults.
2. Git process seam
   - Introduce a GitCommandRunning protocol.
   - LocalGitRepositoryManager depends on protocol, default implementation wraps Process.
3. HTTP client seam
   - Introduce a lightweight HTTP transport protocol for GET and POST.
   - Copilot and sidecar clients use protocol with URLSession-backed default implementation.
4. Time and async seam for retry logic
   - Add delay scheduler abstraction where retries/backoff are asserted.
5. Test fixtures and builders
   - Add shared test builders for ChatMessage, GitFileChange, model catalog payloads, and sidecar health responses.

Current status:
- Implemented: shared fixture/builders for ChatMessage, model catalog payload JSON shapes, and sidecar health snapshots in `mac-copilotTests/Support/TestFixtures.swift`.
- Implemented: fixture smoke tests in `mac-copilotTests/TestingPlanFixturesSmokeTests.swift`.
- Pending: add shared GitFileChange fixture helper alongside upcoming Git-focused unit test phase.

Exit criteria:
- No behavior change.
- All new seams covered by at least smoke-level tests.
- CI remains green.

### Final audit snapshot (2026-02-26)

Implemented in Phase 0 so far:
- Sidecar lifecycle DI seams (`SidecarManager` dependency injection for preflight/runtime/process/restart/log/scheduler).
- Git command runner seam (`GitCommandRunning` + default `LocalGitCommandRunner`).
- HTTP transport seam (`HTTPDataTransporting`) for model catalog and sidecar HTTP clients.
- Sidecar health probe seams (`SidecarHealthDataFetching` + `BlockingDelaySleeping`).
- Control Center runtime utility seams (`ControlCenterCommandRunning` + `ControlCenterFileManaging` + `DateProviding` + HTTP/delay injection).
- Deterministic jitter seam (`SidecarRestartPolicy` `jitterProvider` injection).
- Clock seam consistency (`ClockProviding` in sidecar runtime manager/probe decisions).
- Async delay seam (`AsyncDelayScheduling`) for retry loops.
- Control Center runtime manager process seams (`ControlCenterCommandStatusRunning` + injected clock/HTTP/delay for health polling and capture paths).
- Sidecar runtime utility runner/sleep seams (`SidecarCommandRunning` + injected blocking sleeper).
- Git filesystem check seam (`GitFileSystemChecking` in `LocalGitRepositoryManager`).
- Simple HTML adapter filesystem seam (`ControlCenterFileManaging` injection).
- Shared test fixtures/builders and fixture smoke tests.

Remaining testability gaps to close before heavy Phase 1 test authoring:
None.

---

## Primary priority track (next 5 phases)

### Phase 1: Sidecar lifecycle core unit tests

Targets:
- SidecarManager
- SidecarStateMachine
- SidecarRestartPolicy

Cases:
- Healthy reuse path when external sidecar exists.
- Start ignored while already starting.
- Replace stale process path.
- Retry scheduling and guard trip behavior.
- Termination handling for intentional vs crash.

Exit criteria:
- High confidence in start/reuse/retry state transitions.

Current progress (2026-02-26):
- Implemented `mac-copilotTests/SidecarLifecyclePhase1Tests.swift` for `SidecarRestartPolicy`, `SidecarStateMachine`, and `SidecarManager` core flows.
- Added deterministic coverage for healthy reuse, stale handle clear/start, readiness failure retry scheduling, retry guard trip, and crash vs intentional termination behavior.
- Focused run passed: `xcodebuild test -project mac-copilot.xcodeproj -scheme mac-copilot -destination 'platform=macOS' -only-testing:mac-copilotTests/SidecarLifecyclePhase1Tests`.

### Phase 2: Chat model and send flow unit tests

Targets:
- ChatViewModel plus SendFlow and ModelCatalog extensions.
- CopilotModelCatalogClient decoding path.

Cases:
- Model catalog decode across multiple payload shapes.
- Empty/error catalog handling without silent fallback.
- Model reload triggers and selection retention.
- Send flow state transitions, tool/status accumulation, completion/failure paths.

Exit criteria:
- Regressions around model loading and send flow are covered.

### Phase 3: Git domain/data unit tests

Targets:
- LocalGitRepositoryParsing
- LocalGitRepositoryManager with runner fake

Cases:
- Branch parsing edge cases.
- Numstat aggregation and rename normalization.
- File state mapping and line count fallback.
- Commit flow: empty message, stage fail, commit fail.

Exit criteria:
- Git panel correctness no longer depends on manual validation.

### Phase 4: Integration tests for persistence and sidecar payloads

Targets:
- SwiftData repositories for project/chat.
- Companion chat store and persistence modules.
- Copilot model fetch and prompt route payload contracts.

Cases:
- Import snapshot merge behavior.
- Chat/message pagination and ordering.
- Persist/load roundtrip integrity.

Exit criteria:
- Data integrity validated across read/write boundaries.

### Phase 5: Critical smoke UI and E2E tests

Targets:
- App launch and auth gate.
- Project create/open and chat selection.
- Send prompt and streaming response appears.
- Control Center start and logs visible.

Cases:
- One happy-path suite per major user journey.
- One regression suite for previously fixed composer/scroll issues.

Exit criteria:
- Release-blocking flows are covered by automated smoke tests.

---

## Secondary priority track (additional 5 phases)

### Secondary Phase 1: Component-level view model tests

Targets:
- ContextPaneViewModel
- ControlCenterViewModel
- ModelsManagementViewModel

Focus:
- Command enablement rules, loading flags, and error messaging.

### Secondary Phase 2: Sidecar integration resilience tests

Targets:
- SidecarHTTPClient with controlled transport fake.

Focus:
- Recoverable error retry behavior.
- Sidecar-not-ready escalation and user-safe messaging.

### Secondary Phase 3: Prompt protocol and streaming contract tests

Targets:
- Prompt route and stream payload formatting.
- Tool execution event transformation.

Focus:
- Data frame shape compatibility and done/error framing.

### Secondary Phase 4: Broader UI regression suites

Targets:
- Sidebar project/chat operations.
- Git panel interactions.
- Models management sheet.

Focus:
- Accessibility labels, stable identifiers, and route/state restoration.

### Secondary Phase 5: Non-functional quality gates

Targets:
- Performance and reliability checks in CI.

Focus:
- Startup timing budget guard.
- Memory footprint checks for long chat transcripts.
- Flake tracker and quarantine workflow.

---

## Delivery cadence

Recommended order:
1. Complete Phase 0 first.
2. Execute Primary Phases 1 to 5 in order.
3. Then execute Secondary Phases 1 to 5.

Suggested pacing:
- Week 1: Phase 0 plus Primary Phase 1
- Week 2: Primary Phases 2 and 3
- Week 3: Primary Phases 4 and 5
- Week 4+: Secondary phases in sequence

## Definition of done per phase

Each phase is done only when:
- Test cases are implemented and green locally and in CI.
- New tests are deterministic (no timing flake under normal CI load).
- A short phase summary is added to PR description (scope, risk, follow-up).
