import Foundation
import Combine
import FactoryKit

@MainActor
final class AppEnvironment: ObservableObject {
    enum LaunchPhase {
        case checking
        case ready
    }

    let authViewModel: AuthViewModel
    let shellViewModel: ShellViewModel
    @Published private(set) var launchPhase: LaunchPhase = .checking

    let modelRepository: ModelListingRepository
    let controlCenterResolver: ProjectControlCenterResolver
    let controlCenterRuntimeManager: ControlCenterRuntimeManager
    let gitRepositoryManager: GitRepositoryManaging
    let modelSelectionStore: ModelSelectionStore
    let mcpToolsStore: MCPToolsStore
    let companionStatusStore: CompanionStatusStore
    let profileViewModel: ProfileViewModel
    let projectCreationService: ProjectCreationService

    private let bootstrapService: AppBootstrapService
    private let chatViewModelProvider: ChatViewModelProvider

    init(container: Container = .shared) {
        self.authViewModel = container.authViewModel()
        let chatRepository = container.chatRepository()
        self.shellViewModel = ShellViewModel(
            projectRepository: container.projectRepository(),
            chatRepository: chatRepository
        )
        self.modelRepository = container.modelRepository()
        self.controlCenterResolver = container.controlCenterResolver()
        self.controlCenterRuntimeManager = container.controlCenterRuntimeManager()
        self.gitRepositoryManager = container.gitRepositoryManager()
        self.modelSelectionStore = container.modelSelectionStore()
        self.mcpToolsStore = container.mcpToolsStore()
        self.companionStatusStore = container.companionStatusStore()
        self.profileViewModel = container.profileViewModel()
        self.projectCreationService = container.projectCreationService()
        self.bootstrapService = container.appBootstrapService()
        self.chatViewModelProvider = container.chatViewModelProvider()
    }

    func bootstrapIfNeeded() async {
        launchPhase = .checking
        await bootstrapService.bootstrapIfNeeded()
        launchPhase = .ready
    }

    func chatViewModel(for chat: ChatThreadRef, project: ProjectRef) -> ChatViewModel {
        chatViewModelProvider.viewModel(for: chat, project: project)
    }

    static func preview() -> AppEnvironment {
        Container.shared.appEnvironment()
    }
}
