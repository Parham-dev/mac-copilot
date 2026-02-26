# CopilotForge Testing Roadmap and Execution Checklist

## Purpose

This document is a handoff checklist for an independent agent to continue test authoring without prior conversation context.

Primary goals:
- Start from app-level coverage, then move feature-by-feature.
- Follow test pyramid targets strictly.
- Maintain deterministic, fast tests with focused runs.

## Test pyramid and quotas

- Unit tests: 70%
- Integration tests: 20%
- UI/E2E smoke tests: 10%

Working rule:
- For every new UI test added, add 4-6 unit/integration tests in same or adjacent feature.

## Current baseline (already implemented)

Completed suites:
- `mac-copilotTests/TestingPlanFixturesSmokeTests.swift`
- `mac-copilotTests/SidecarLifecyclePhase1Tests.swift`
- `mac-copilotTests/CopilotModelCatalogClientPhase2Tests.swift`
- `mac-copilotTests/ChatViewModelPhase2Tests.swift`
- `mac-copilotTests/GitDomainPhase3Tests.swift`
- `mac-copilotTests/PersistencePhase4IntegrationTests.swift`
- `mac-copilotTests/PayloadContractsPhase4Tests.swift`
- `mac-copilotUITests/mac_copilotUITests.swift` (initial Phase 5 smoke)

These should be kept green while expanding coverage.

## Independent-agent operating protocol

1. Work in this order:
   - App and bootstrap
   - Feature domain/data/viewmodel
   - UI smoke and regression
2. Add tests in focused files named by phase or feature scope.
3. After each feature batch, run focused `xcodebuild -only-testing` for changed suites.
4. If UI flow is non-deterministic, use `XCTSkip` with explicit reason instead of flaky assertions.
5. Update this file after each feature batch.

## Run commands (canonical)

- Full unit/integration target:
  - `xcodebuild test -project mac-copilot.xcodeproj -scheme mac-copilot -destination 'platform=macOS,arch=arm64' -only-testing:mac-copilotTests`
- UI smoke target:
  - `xcodebuild test -project mac-copilot.xcodeproj -scheme mac-copilot -destination 'platform=macOS,arch=arm64' -only-testing:mac-copilotUITests`
- Single suite pattern:
  - `xcodebuild test -project mac-copilot.xcodeproj -scheme mac-copilot -destination 'platform=macOS,arch=arm64' -only-testing:mac-copilotTests/<SuiteName>`

## Master roadmap (execution order)

### Phase A: App-level foundation (start here)

Checklist:
- [ ] App bootstraps onboarding vs authenticated shell deterministically.
- [ ] Environment/container wiring verified for all injected dependencies.
- [x] Persistent stores roundtrip correctly for model/tool preferences.

Progress notes:
- 2026-02-26: Added `mac-copilotTests/AppStoresPhaseAUnitTests.swift` covering `AppBootstrapService`, `ModelSelectionStore`, `MCPToolsStore`, and `CompanionStatusStore`. Focused run passed with `-only-testing:mac-copilotTests/AppStoresPhaseAUnitTests`.

Target files:
- `mac-copilot/App/Bootstrap/mac_copilotApp.swift`
- `mac-copilot/App/Bootstrap/WindowFrameGuard.swift`
- `mac-copilot/App/Environment/AppEnvironment.swift`
- `mac-copilot/App/Environment/AppContainer.swift`
- `mac-copilot/App/Environment/AppBootstrapService.swift`
- `mac-copilot/App/Environment/AuthEnvironment.swift`
- `mac-copilot/App/Environment/ShellEnvironment.swift`
- `mac-copilot/App/Environment/CompanionEnvironment.swift`
- `mac-copilot/App/Environment/ChatViewModelProvider.swift`
- `mac-copilot/App/Environment/Stores/ModelSelectionStore.swift`
- `mac-copilot/App/Environment/Stores/ModelSelectionPreferencesStore.swift`
- `mac-copilot/App/Environment/Stores/MCPToolsStore.swift`
- `mac-copilot/App/Environment/Stores/MCPToolsPreferencesStore.swift`
- `mac-copilot/App/Environment/Stores/CompanionStatusStore.swift`

Test types:
- Unit: env and store behaviors.
- Integration: bootstrap and persistence boundaries.
- UI smoke: launch path assertions.

### Phase B: Shared infrastructure

Checklist:
- [ ] HTTP transports have contract tests (status handling, payload pass-through).
- [ ] Delay/clock seams are used in tests; no real sleeps in unit tests.
- [ ] SwiftData stack fallback behavior is covered.

Target files:
- `mac-copilot/Shared/Data/Networking/HTTPDataTransport.swift`
- `mac-copilot/Shared/Data/Networking/HTTPLineStreamTransport.swift`
- `mac-copilot/Shared/Data/Async/AsyncDelayScheduler.swift`
- `mac-copilot/Shared/Data/Time/ClockProvider.swift`
- `mac-copilot/Shared/Data/Persistence/SwiftDataStack.swift`
- `mac-copilot/Shared/Data/Persistence/SwiftDataStoreProviding.swift`

### Phase C: Feature-by-feature checklist

#### 1) Auth

Checklist:
- [ ] Device flow start/poll/sign-out state transitions.
- [ ] Repository state publishing behavior.
- [ ] Sidecar auth client request/response mapping and error handling.
- [ ] Onboarding and auth viewmodel interaction state.

Target files:
- `mac-copilot/Features/Auth/Data/GitHubAuthRepository.swift`
- `mac-copilot/Features/Auth/Data/GitHubAuthService.swift`
- `mac-copilot/Features/Auth/Data/Support/SidecarAuthClient.swift`
- `mac-copilot/Features/Auth/Data/Support/KeychainTokenStore.swift`
- `mac-copilot/Features/Auth/Data/Support/AuthAPIModels.swift`
- `mac-copilot/Features/Auth/Domain/Entities/AuthSessionState.swift`
- `mac-copilot/Features/Auth/Domain/UseCases/AuthUseCases.swift`
- `mac-copilot/Features/Auth/Presentation/AuthViewModel.swift`
- `mac-copilot/Features/Auth/Presentation/AuthView.swift`
- `mac-copilot/Features/Auth/Presentation/OnboardingRootView.swift`

#### 2) Chat

Checklist:
- [x] Model catalog and send-flow core coverage.
- [ ] Chat session coordinator persistence behavior.
- [ ] Transcript/composer state behavior around metadata/status/tool chips.
- [ ] Prompt stream protocol edge cases and marker filtering.
- [ ] SwiftData chat repo decode/invalid-role resilience.

Target files:
- `mac-copilot/Features/Chat/Data/CopilotAPIService.swift`
- `mac-copilot/Features/Chat/Data/CopilotModelCatalogClient.swift`
- `mac-copilot/Features/Chat/Data/CopilotPromptStreamClient.swift`
- `mac-copilot/Features/Chat/Data/CopilotPromptRepository.swift`
- `mac-copilot/Features/Chat/Data/Local/SwiftDataChatRepository.swift`
- `mac-copilot/Features/Chat/Data/Local/Models/ChatThreadEntity.swift`
- `mac-copilot/Features/Chat/Data/Local/Models/ChatMessageEntity.swift`
- `mac-copilot/Features/Chat/Domain/UseCases/SendPromptUseCase.swift`
- `mac-copilot/Features/Chat/Domain/UseCases/FetchModelsUseCase.swift`
- `mac-copilot/Features/Chat/Domain/UseCases/FetchModelCatalogUseCase.swift`
- `mac-copilot/Features/Chat/Presentation/ViewModel/ChatViewModel.swift`
- `mac-copilot/Features/Chat/Presentation/ViewModel/ChatViewModel+SendFlow.swift`
- `mac-copilot/Features/Chat/Presentation/ViewModel/ChatViewModel+ModelCatalog.swift`
- `mac-copilot/Features/Chat/Presentation/ViewModel/ChatViewModel+Metadata.swift`
- `mac-copilot/Features/Chat/Presentation/Support/ChatSessionCoordinator.swift`
- `mac-copilot/Features/Chat/Presentation/ChatView.swift`
- `mac-copilot/Features/Chat/Presentation/Components/ChatComposerView.swift`
- `mac-copilot/Features/Chat/Presentation/Components/ChatTranscriptView.swift`
- `mac-copilot/Features/Chat/Support/PromptTrace.swift`

#### 3) Sidecar

Checklist:
- [x] Lifecycle policy/state machine baseline complete.
- [ ] Preflight and node/runtime resolution negative paths.
- [ ] Health probe and HTTP client retry/escalation matrix.
- [ ] Runtime utilities process command and stale-process handling.

Target files:
- `mac-copilot/Features/Sidecar/Data/Lifecycle/SidecarManager.swift`
- `mac-copilot/Features/Sidecar/Data/Lifecycle/SidecarStateMachine.swift`
- `mac-copilot/Features/Sidecar/Data/Lifecycle/SidecarRestartPolicy.swift`
- `mac-copilot/Features/Sidecar/Data/Runtime/SidecarPreflight.swift`
- `mac-copilot/Features/Sidecar/Data/Runtime/SidecarHealthProbe.swift`
- `mac-copilot/Features/Sidecar/Data/Runtime/SidecarRuntimeUtilities.swift`
- `mac-copilot/Features/Sidecar/Data/Runtime/SidecarNodeRuntimeResolver.swift`
- `mac-copilot/Features/Sidecar/Data/Runtime/SidecarScriptResolver.swift`
- `mac-copilot/Features/Sidecar/Data/Runtime/SidecarReusePolicy.swift`
- `mac-copilot/Features/Sidecar/Data/Support/SidecarHTTPClient.swift`
- `mac-copilot/Features/Sidecar/Data/Process/SidecarProcessController.swift`
- `mac-copilot/Features/Sidecar/Data/Process/SidecarCommandRunner.swift`

#### 4) Shell + Git + Layout

Checklist:
- [x] Git parser/manager baseline complete.
- [ ] Shell selection, chat creation/deletion, project expansion state.
- [ ] Context pane routing and refresh behavior.
- [ ] Models/MCP management viewmodel command-state logic.

Target files:
- `mac-copilot/Features/Shell/Presentation/ShellViewModel.swift`
- `mac-copilot/Features/Shell/Presentation/Support/ShellWorkspaceCoordinator.swift`
- `mac-copilot/Features/Shell/Presentation/Support/ProjectCreationService.swift`
- `mac-copilot/Features/Shell/Presentation/ContextPaneViewModel.swift`
- `mac-copilot/Features/Shell/Presentation/ContentView.swift`
- `mac-copilot/Features/Shell/Presentation/Components/Layout/ShellDetailPaneView.swift`
- `mac-copilot/Features/Shell/Presentation/Components/Layout/ShellSidebarView.swift`
- `mac-copilot/Features/Shell/Presentation/Components/Layout/ShellSidebarBottomBarView.swift`
- `mac-copilot/Features/Shell/Presentation/Components/Layout/ShellSidebarProjectsHeaderView.swift`
- `mac-copilot/Features/Shell/Presentation/Components/Layout/ControlCenterView.swift`
- `mac-copilot/Features/Shell/Presentation/Components/Layout/ControlCenterViewModel.swift`
- `mac-copilot/Features/Shell/Data/LocalGitRepositoryManager.swift`
- `mac-copilot/Features/Shell/Data/LocalGitRepositoryParsing.swift`
- `mac-copilot/Features/Shell/Data/LocalGitCommandRunner.swift`

#### 5) Control Center

Checklist:
- [ ] Project adapter resolution precedence by project shape.
- [ ] Runtime manager start/stop/refresh state transitions.
- [ ] Runtime diagnostics/logging behavior across adapters.
- [ ] Utility command/file/network/delay seams covered.

Target files:
- `mac-copilot/Features/ControlCenter/Domain/UseCases/ProjectControlCenterResolver.swift`
- `mac-copilot/Features/ControlCenter/Data/RuntimeManager/ControlCenterRuntimeManager.swift`
- `mac-copilot/Features/ControlCenter/Data/RuntimeManager/ControlCenterRuntimeManager+Startup.swift`
- `mac-copilot/Features/ControlCenter/Data/RuntimeManager/ControlCenterRuntimeManager+Process.swift`
- `mac-copilot/Features/ControlCenter/Data/RuntimeManager/ControlCenterRuntimeManager+Logging.swift`
- `mac-copilot/Features/ControlCenter/Data/RuntimeManager/ControlCenterRuntimeManager+Diagnostics.swift`
- `mac-copilot/Features/ControlCenter/Data/ControlCenterRuntimeUtilities.swift`
- `mac-copilot/Features/ControlCenter/Data/Adapters/Project/NodeControlCenterAdapter.swift`
- `mac-copilot/Features/ControlCenter/Data/Adapters/Project/PythonProjectControlCenterAdapter.swift`
- `mac-copilot/Features/ControlCenter/Data/Adapters/Project/SimpleHTMLControlCenterAdapter.swift`
- `mac-copilot/Features/ControlCenter/Data/Adapters/Runtime/NodeRuntimeAdapter.swift`
- `mac-copilot/Features/ControlCenter/Data/Adapters/Runtime/PythonRuntimeAdapter.swift`
- `mac-copilot/Features/ControlCenter/Data/Adapters/Runtime/SimpleHTMLRuntimeAdapter.swift`

#### 6) Project

Checklist:
- [ ] Project creation/fetch ordering and mapping.
- [ ] SwiftData project persistence error handling.

Target files:
- `mac-copilot/Features/Project/Data/Local/SwiftDataProjectRepository.swift`
- `mac-copilot/Features/Project/Data/Local/Models/ProjectEntity.swift`
- `mac-copilot/Features/Project/Domain/UseCases/ProjectUseCases.swift`

#### 7) Profile

Checklist:
- [ ] Profile fetch happy/failure mapping.
- [ ] ViewModel loading/error state transitions.
- [ ] Endpoint and Copilot status card rendering logic.

Target files:
- `mac-copilot/Features/Profile/Data/GitHubProfileRepository.swift`
- `mac-copilot/Features/Profile/Domain/UseCases/FetchProfileUseCase.swift`
- `mac-copilot/Features/Profile/Presentation/ProfileViewModel.swift`
- `mac-copilot/Features/Profile/Presentation/ProfileView.swift`
- `mac-copilot/Features/Profile/Presentation/Components/CopilotStatusCardView.swift`
- `mac-copilot/Features/Profile/Presentation/Components/EndpointCheckCardView.swift`
- `mac-copilot/Features/Profile/Presentation/Components/UserProfileSummaryView.swift`

#### 8) Companion

Checklist:
- [x] Snapshot payload contract baseline complete.
- [ ] Connection service lifecycle + polling/error paths.
- [ ] Companion client decode/error handling matrix.
- [ ] In-memory service parity tests against expected API.

Target files:
- `mac-copilot/Features/Companion/Data/SidecarCompanionConnectionService.swift`
- `mac-copilot/Features/Companion/Data/Support/SidecarCompanionClient.swift`
- `mac-copilot/Features/Companion/Data/SidecarCompanionWorkspaceSyncService.swift`
- `mac-copilot/Features/Companion/Data/InMemoryCompanionConnectionService.swift`

### Phase D: Sidecar TypeScript contract and persistence tests

Checklist:
- [ ] Companion store snapshot merge and pagination.
- [ ] Companion persistence read/write fallback behavior.
- [ ] Prompt route framing and protocol markup integrity.
- [ ] Model catalog and session manager contract behavior.

Target files:
- `sidecar/src/companion/chatStore.ts`
- `sidecar/src/companion/chatStorePersistence.ts`
- `sidecar/src/companion/persistence.ts`
- `sidecar/src/companion/routes.ts`
- `sidecar/src/companion/store.ts`
- `sidecar/src/promptRoute.ts`
- `sidecar/src/promptStreaming/protocolMarkup.ts`
- `sidecar/src/promptStreaming/toolExecution.ts`
- `sidecar/src/copilot/copilotModelCatalog.ts`
- `sidecar/src/copilot/copilotPromptStreaming.ts`
- `sidecar/src/copilot/copilotSessionManager.ts`
- `sidecar/src/sidecarRuntime.ts`
- `sidecar/src/index.ts`

## UI smoke/E2E checklist (Phase 5 target)

Current:
- [x] Launch path smoke (`onboarding` vs `shell`) in `mac-copilotUITests/mac_copilotUITests.swift`
- [x] Guarded chat composer smoke in `mac-copilotUITests/mac_copilotUITests.swift`

Remaining:
- [ ] Project create/open smoke (stable deterministic fixture project)
- [ ] Chat select + send smoke (assert streamed assistant text appears)
- [ ] Control Center start/open/logs smoke
- [ ] Regression smoke for composer growth and transcript auto-scroll anchor

UI files:
- `mac-copilotUITests/mac_copilotUITests.swift`
- `mac-copilotUITests/mac_copilotUITestsLaunchTests.swift`

## Definition of done (per feature batch)

A batch is complete only when all are true:
- [ ] New tests pass in focused local run.
- [ ] Existing related suites remain green.
- [ ] No new flaky waits/sleeps; deterministic assertions only.
- [ ] This checklist is updated with `[x]` statuses and notes.

## Naming conventions for new tests

- Unit suites: `<Feature><Scope>UnitTests.swift`
- Integration suites: `<Feature><Scope>IntegrationTests.swift`
- UI suites: `<Feature><Scope>UITests.swift`

Examples:
- `AuthViewModelUnitTests.swift`
- `ControlCenterRuntimeManagerIntegrationTests.swift`
- `ShellSmokeUITests.swift`

## Suggested next 3 concrete batches

1) App + stores batch
- [x] Add tests for `AppBootstrapService`, `ModelSelectionStore`, `MCPToolsStore`, `CompanionStatusStore`.

2) Auth + Profile batch
- Add repository/use-case/viewmodel unit tests.

3) Control Center batch
- Add resolver/runtime manager integration tests with fake command runner and health transport.
