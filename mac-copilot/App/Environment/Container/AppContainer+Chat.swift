import Foundation
import FactoryKit

extension Container {
    var promptApiService: Factory<CopilotAPIService> {
        self { @MainActor in
            let sidecarLifecycle = self.sidecarLifecycleManager()
            return CopilotAPIService(
                ensureSidecarRunning: {
                    sidecarLifecycle.startIfNeeded()
                }
            )
        }
            .singleton
    }

    var copilotPromptRepository: Factory<CopilotPromptRepository> {
        self { @MainActor in CopilotPromptRepository(apiService: self.promptApiService()) }
            .singleton
    }

    var promptRepository: Factory<any PromptStreamingRepository> {
        self { @MainActor in self.copilotPromptRepository() }
            .singleton
    }

    var modelRepository: Factory<any ModelListingRepository> {
        self { @MainActor in self.copilotPromptRepository() }
            .singleton
    }

    var chatViewModelProvider: Factory<ChatViewModelProvider> {
        self { @MainActor in
            ChatViewModelProvider(
                promptRepository: self.promptRepository(),
                modelRepository: self.modelRepository(),
                chatRepository: self.chatRepository(),
                modelSelectionStore: self.modelSelectionStore(),
                nativeToolsStore: self.nativeToolsStore(),
                chatEventsStore: self.chatEventsStore()
            )
        }
        .singleton
    }
}