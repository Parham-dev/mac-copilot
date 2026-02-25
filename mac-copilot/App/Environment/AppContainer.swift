import Foundation
import FactoryKit

extension Container {
    var sidecarLifecycleManager: Factory<any SidecarLifecycleManaging> {
        self { @MainActor in SidecarManager.shared }
            .singleton
    }

    var swiftDataStack: Factory<any SwiftDataStoreProviding> {
        self { @MainActor in SwiftDataStack() }
            .singleton
    }

    var modelSelectionPreferencesStore: Factory<ModelSelectionPreferencesStoring> {
        self { @MainActor in UserDefaultsModelSelectionPreferencesStore() }
            .singleton
    }

    var mcpToolsPreferencesStore: Factory<MCPToolsPreferencesStoring> {
        self { @MainActor in UserDefaultsMCPToolsPreferencesStore() }
            .singleton
    }

    var companionConnectionService: Factory<any CompanionConnectionServicing> {
        self { @MainActor in
            let client = SidecarCompanionClient(sidecarLifecycle: self.sidecarLifecycleManager())
            return SidecarCompanionConnectionService(client: client)
        }
            .singleton
    }

    var gitRepositoryManager: Factory<any GitRepositoryManaging> {
        self { @MainActor in LocalGitRepositoryManager() }
            .singleton
    }

    var authService: Factory<GitHubAuthService> {
        self { @MainActor in
            let client = SidecarAuthClient(sidecarLifecycle: self.sidecarLifecycleManager())
            return GitHubAuthService(sidecarClient: client)
        }
            .singleton
    }

    var authRepository: Factory<any AuthRepository> {
        self { @MainActor in GitHubAuthRepository(service: self.authService()) }
            .singleton
    }

    var authViewModel: Factory<AuthViewModel> {
        self { @MainActor in AuthViewModel(repository: self.authRepository()) }
            .singleton
    }

    var projectRepository: Factory<any ProjectRepository> {
        self { @MainActor in SwiftDataProjectRepository(context: self.swiftDataStack().context) }
            .singleton
    }

    var chatRepository: Factory<any ChatRepository> {
        self { @MainActor in SwiftDataChatRepository(context: self.swiftDataStack().context) }
            .singleton
    }

    var promptApiService: Factory<CopilotAPIService> {
        self { @MainActor in CopilotAPIService() }
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

    var profileRepository: Factory<any ProfileRepository> {
        self { @MainActor in GitHubProfileRepository() }
            .singleton
    }

    var controlCenterResolver: Factory<ProjectControlCenterResolver> {
        self { @MainActor in
            ProjectControlCenterResolver(adapters: [
                SimpleHTMLControlCenterAdapter(),
            ])
        }
        .singleton
    }

    var controlCenterRuntimeManager: Factory<ControlCenterRuntimeManager> {
        self { @MainActor in
            ControlCenterRuntimeManager(adapters: [
                NodeRuntimeAdapter(),
                PythonRuntimeAdapter(),
                SimpleHTMLRuntimeAdapter(),
            ])
        }
        .singleton
    }

    var appEnvironment: Factory<AppEnvironment> {
        self { @MainActor in AppEnvironment(container: self) }
            .singleton
    }
}