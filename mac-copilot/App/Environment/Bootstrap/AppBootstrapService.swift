import Foundation

@MainActor
final class AppBootstrapService {
    private let sidecarLifecycle: SidecarLifecycleManaging
    private let authViewModel: AuthViewModel
    private let companionStatusStore: CompanionStatusStore
    private let companionWorkspaceSyncService: CompanionWorkspaceSyncing
    private var didBootstrap = false

    init(
        sidecarLifecycle: SidecarLifecycleManaging,
        authViewModel: AuthViewModel,
        companionStatusStore: CompanionStatusStore,
        companionWorkspaceSyncService: CompanionWorkspaceSyncing
    ) {
        self.sidecarLifecycle = sidecarLifecycle
        self.authViewModel = authViewModel
        self.companionStatusStore = companionStatusStore
        self.companionWorkspaceSyncService = companionWorkspaceSyncService
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        sidecarLifecycle.startIfNeeded()
        await companionWorkspaceSyncService.syncWorkspaceSnapshot()
        await authViewModel.restoreSessionIfNeeded()
        await companionStatusStore.refreshStatus()
    }
}
