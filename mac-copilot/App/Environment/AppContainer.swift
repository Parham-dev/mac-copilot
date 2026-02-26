import Foundation
import FactoryKit

extension Container {
    var sidecarLifecycleManager: Factory<any SidecarLifecycleManaging> {
        self { @MainActor in SidecarManager() }
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

    var modelSelectionStore: Factory<ModelSelectionStore> {
        self { @MainActor in ModelSelectionStore(preferencesStore: self.modelSelectionPreferencesStore()) }
            .singleton
    }

    var mcpToolsStore: Factory<MCPToolsStore> {
        self { @MainActor in MCPToolsStore(preferencesStore: self.mcpToolsPreferencesStore()) }
            .singleton
    }

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

    var profileViewModel: Factory<ProfileViewModel> {
        self { @MainActor in
            ProfileViewModel(fetchProfileUseCase: FetchProfileUseCase(repository: self.profileRepository()))
        }
        .singleton
    }

    var controlCenterResolver: Factory<ProjectControlCenterResolver> {
        self { @MainActor in
            ProjectControlCenterResolver(adapters: [
                NodeControlCenterAdapter(),
                PythonProjectControlCenterAdapter(),
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

    var chatViewModelProvider: Factory<ChatViewModelProvider> {
        self { @MainActor in
            ChatViewModelProvider(
                promptRepository: self.promptRepository(),
                modelRepository: self.modelRepository(),
                chatRepository: self.chatRepository(),
                modelSelectionStore: self.modelSelectionStore(),
                mcpToolsStore: self.mcpToolsStore()
            )
        }
        .singleton
    }

    var projectCreationService: Factory<ProjectCreationService> {
        self { @MainActor in ProjectCreationService() }
            .singleton
    }

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