import Foundation

@MainActor
final class AppBootstrapService {
    private let sidecarLifecycle: SidecarLifecycleManaging
    private let authViewModel: AuthViewModel
    private let companionStatusStore: CompanionStatusStore
    private var didBootstrap = false

    init(
        sidecarLifecycle: SidecarLifecycleManaging,
        authViewModel: AuthViewModel,
        companionStatusStore: CompanionStatusStore
    ) {
        self.sidecarLifecycle = sidecarLifecycle
        self.authViewModel = authViewModel
        self.companionStatusStore = companionStatusStore
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        sidecarLifecycle.startIfNeeded()
        await authViewModel.restoreSessionIfNeeded()
        await companionStatusStore.refreshStatus()
    }
}
