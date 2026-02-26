import Foundation
import FactoryKit

extension Container {
    var appBootstrapService: Factory<AppBootstrapService> {
        self { @MainActor in
            AppBootstrapService(
                sidecarLifecycle: self.sidecarLifecycleManager(),
                authViewModel: self.authViewModel(),
                companionStatusStore: self.companionStatusStore(),
                companionWorkspaceSyncService: self.companionWorkspaceSyncService()
            )
        }
        .singleton
    }

    var appEnvironment: Factory<AppEnvironment> {
        self { @MainActor in AppEnvironment(container: self) }
            .singleton
    }
}