import Foundation
import FactoryKit

extension Container {
    var companionConnectionService: Factory<any CompanionConnectionServicing> {
        self { @MainActor in
            let client = SidecarCompanionClient(sidecarLifecycle: self.sidecarLifecycleManager())
            return SidecarCompanionConnectionService(client: client)
        }
            .singleton
    }

    var companionStatusStore: Factory<CompanionStatusStore> {
        self { @MainActor in CompanionStatusStore(service: self.companionConnectionService()) }
            .singleton
    }

    var companionWorkspaceSyncService: Factory<any CompanionWorkspaceSyncing> {
        self { @MainActor in
            SidecarCompanionWorkspaceSyncService(
                projectRepository: self.projectRepository(),
                chatRepository: self.chatRepository(),
                sidecarLifecycle: self.sidecarLifecycleManager()
            )
        }
            .singleton
    }
}