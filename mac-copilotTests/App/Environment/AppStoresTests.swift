import Foundation
import Combine
import FactoryKit
import Testing
@testable import mac_copilot

@MainActor
struct AppStoresTests {
    @Test(.tags(.unit, .async_)) func appBootstrapService_runsDependenciesInOrderOnlyOnce() async {
        let recorder = CallRecorder()
        let sidecar = RecordingSidecarLifecycle(recorder: recorder)
        let authRepository = FakeAuthRepository(recorder: recorder)
        let authViewModel = AuthViewModel(repository: authRepository)
        let companionService = RecordingCompanionConnectionService(recorder: recorder)
        let companionStatusStore = CompanionStatusStore(service: companionService)
        let workspaceSync = RecordingCompanionWorkspaceSyncService(recorder: recorder)

        let service = AppBootstrapService(
            sidecarLifecycle: sidecar,
            authViewModel: authViewModel,
            companionStatusStore: companionStatusStore,
            companionWorkspaceSyncService: workspaceSync
        )

        await service.bootstrapIfNeeded()
        await service.bootstrapIfNeeded()

        #expect(recorder.events == [
            "sidecar.startIfNeeded",
            "workspace.sync",
            "auth.restore",
            "companion.fetchStatus"
        ])
        #expect(sidecar.startIfNeededCount == 1)
        #expect(authRepository.restoreSessionIfNeededCount == 1)
        #expect(workspaceSync.syncCount == 1)
        #expect(companionService.fetchStatusCount == 1)
    }

    @Test(.tags(.unit)) func modelSelectionStore_normalizesPersistsAndBumpsChangeToken() {
        let preferences = InMemoryModelSelectionPreferencesStore([" old ", "gpt-5"])
        let store = ModelSelectionStore(preferencesStore: preferences)

        store.setSelectedModelIDs([" claude ", "", "gpt-5", "CLAUDE", "gpt-5"])

        let selected = store.selectedModelIDs()
        #expect(selected.count == 3)
        #expect(Set(selected) == Set(["CLAUDE", "claude", "gpt-5"]))
        #expect(Set(preferences.storedIDs) == Set(["CLAUDE", "claude", "gpt-5"]))
        #expect(store.changeToken == 1)
    }

    @Test(.tags(.unit)) func mcpToolsStore_normalizesPersistsAndBumpsChangeToken() {
        let preferences = InMemoryMCPToolsPreferencesStore(["old_tool"])
        let store = MCPToolsStore(preferencesStore: preferences)

        store.setEnabledToolIDs([" read_file", "", "list_dir", "read_file "])

        #expect(store.enabledToolIDs() == ["list_dir", "read_file"])
        #expect(preferences.storedIDs == ["list_dir", "read_file"])
        #expect(store.changeToken == 1)
    }

    @Test(.tags(.unit, .async_)) func companionStatusStore_refreshStatus_updatesConnectedStateAndComputedProperties() async {
        let now = Date(timeIntervalSince1970: 1_234)
        let service = RecordingCompanionConnectionService(
            statusSnapshot: CompanionConnectionSnapshot(connectedDeviceName: "Parham iPhone", connectedAt: now)
        )
        let store = CompanionStatusStore(service: service)

        await store.refreshStatus()

        #expect(store.status == .connected(deviceName: "Parham iPhone", connectedAt: now))
        #expect(store.statusLabel == "Connected")
        #expect(store.isConnected)
        #expect(store.connectedDeviceName == "Parham iPhone")
        #expect(!store.isBusy)
        #expect(store.lastErrorMessage == nil)
    }

    @Test(.tags(.unit, .async_)) func companionStatusStore_startPairing_setsPairingState() async {
        let expiresAt = Date(timeIntervalSince1970: 9_999)
        let service = RecordingCompanionConnectionService(
            pairingSession: CompanionPairingSession(code: "ABC123", qrPayload: "payload", expiresAt: expiresAt)
        )
        let store = CompanionStatusStore(service: service)

        await store.startPairing()

        #expect(store.status == .pairing)
        #expect(store.pairingCode == "ABC123")
        #expect(store.pairingQRCodePayload == "payload")
        #expect(store.pairingExpiresAt == expiresAt)
        #expect(!store.isBusy)
    }

    @Test(.tags(.unit, .async_)) func companionStatusStore_disconnect_clearsPairingAndAppliesDisconnectedStatus() async {
        let service = RecordingCompanionConnectionService(
            disconnectSnapshot: CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil)
        )
        let store = CompanionStatusStore(service: service)

        await store.startPairing()
        await store.disconnect()

        #expect(store.status == .disconnected)
        #expect(store.pairingCode == "------")
        #expect(store.pairingQRCodePayload == nil)
        #expect(store.pairingExpiresAt == nil)
        #expect(!store.isBusy)
    }

    @Test(.tags(.unit, .async_)) func companionStatusStore_recordsErrorAndClearsBusyWhenOperationFails() async {
        let service = RecordingCompanionConnectionService(fetchStatusError: CompanionStoreTestError.failed)
        let store = CompanionStatusStore(service: service)

        await store.refreshStatus()

        #expect(store.status == .disconnected)
        #expect(!store.isBusy)
        #expect(store.lastErrorMessage == CompanionStoreTestError.failed.localizedDescription)
    }

    @Test(.tags(.smoke)) func appEnvironment_wiresSharedContainerDependencies() {
        let container = Container.shared
        let environment = AppEnvironment(container: container)

        #expect(environment.authEnvironment.authViewModel === container.authViewModel())
        #expect(environment.projectsEnvironment.modelSelectionStore === container.modelSelectionStore())
        #expect(environment.projectsEnvironment.mcpToolsStore === container.mcpToolsStore())
        #expect(environment.companionEnvironment.companionStatusStore === container.companionStatusStore())
        #expect(environment.profileEnvironment.profileViewModel === container.profileViewModel())
        #expect(environment.projectsEnvironment.projectCreationService === container.projectCreationService())
    }

    @Test(.tags(.smoke)) func appContainer_storeFactoriesReturnSingletonInstances() {
        let container = Container.shared

        #expect(container.modelSelectionStore() === container.modelSelectionStore())
        #expect(container.mcpToolsStore() === container.mcpToolsStore())
        #expect(container.companionStatusStore() === container.companionStatusStore())
        #expect(container.chatViewModelProvider() === container.chatViewModelProvider())
    }
}

// MARK: - App bootstrap-specific test doubles

@MainActor
private final class CallRecorder {
    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private final class RecordingSidecarLifecycle: SidecarLifecycleManaging {
    private let recorder: CallRecorder
    private(set) var startIfNeededCount = 0

    init(recorder: CallRecorder) {
        self.recorder = recorder
    }

    func startIfNeeded() {
        startIfNeededCount += 1
        recorder.record("sidecar.startIfNeeded")
    }

    func restart() {}

    func stop() {}
}

@MainActor
private final class RecordingCompanionWorkspaceSyncService: CompanionWorkspaceSyncing {
    private let recorder: CallRecorder
    private(set) var syncCount = 0

    init(recorder: CallRecorder) {
        self.recorder = recorder
    }

    func syncWorkspaceSnapshot() async {
        syncCount += 1
        recorder.record("workspace.sync")
    }
}

@MainActor
private final class FakeAuthRepository: AuthRepository {
    private let recorder: CallRecorder?
    var state: AuthSessionState = .initial
    var statePublisher: AnyPublisher<AuthSessionState, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = CurrentValueSubject<AuthSessionState, Never>(.initial)
    private(set) var restoreSessionIfNeededCount = 0

    init(recorder: CallRecorder? = nil) {
        self.recorder = recorder
    }

    func restoreSessionIfNeeded() async {
        restoreSessionIfNeededCount += 1
        recorder?.record("auth.restore")
        state.isLoading = false
        subject.send(state)
    }

    func startDeviceFlow() async {}

    func pollForAuthorization() async {}

    func signOut() {}

    func currentAccessToken() -> String? { nil }
}

@MainActor
private final class RecordingCompanionConnectionService: CompanionConnectionServicing {
    private let recorder: CallRecorder?
    private let statusSnapshot: CompanionConnectionSnapshot
    private let pairingSession: CompanionPairingSession
    private let disconnectSnapshot: CompanionConnectionSnapshot
    private let fetchStatusError: Error?

    private(set) var fetchStatusCount = 0

    init(
        recorder: CallRecorder? = nil,
        statusSnapshot: CompanionConnectionSnapshot = CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil),
        pairingSession: CompanionPairingSession = CompanionPairingSession(code: "XYZ789", qrPayload: "qr", expiresAt: Date(timeIntervalSince1970: 500)),
        disconnectSnapshot: CompanionConnectionSnapshot = CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil),
        fetchStatusError: Error? = nil
    ) {
        self.recorder = recorder
        self.statusSnapshot = statusSnapshot
        self.pairingSession = pairingSession
        self.disconnectSnapshot = disconnectSnapshot
        self.fetchStatusError = fetchStatusError
    }

    func fetchStatus() async throws -> CompanionConnectionSnapshot {
        fetchStatusCount += 1
        recorder?.record("companion.fetchStatus")
        if let fetchStatusError {
            throw fetchStatusError
        }
        return statusSnapshot
    }

    func startPairing() async throws -> CompanionPairingSession {
        pairingSession
    }

    func disconnect() async throws -> CompanionConnectionSnapshot {
        disconnectSnapshot
    }
}

private enum CompanionStoreTestError: LocalizedError {
    case failed

    var errorDescription: String? {
        "companion request failed"
    }
}
