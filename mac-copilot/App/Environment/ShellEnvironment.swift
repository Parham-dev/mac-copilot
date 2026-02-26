import Foundation
import Combine

@MainActor
final class ShellEnvironment: ObservableObject {
    let shellViewModel: ShellViewModel
    let modelRepository: ModelListingRepository
    let controlCenterResolver: ProjectControlCenterResolver
    let controlCenterRuntimeManager: ControlCenterRuntimeManager
    let gitRepositoryManager: GitRepositoryManaging
    let promptRepository: PromptStreamingRepository
    let modelSelectionStore: ModelSelectionStore
    let mcpToolsStore: MCPToolsStore
    let profileViewModel: ProfileViewModel
    let projectCreationService: ProjectCreationService

    private let chatViewModelProvider: ChatViewModelProvider

    init(
        shellViewModel: ShellViewModel,
        modelRepository: ModelListingRepository,
        controlCenterResolver: ProjectControlCenterResolver,
        controlCenterRuntimeManager: ControlCenterRuntimeManager,
        gitRepositoryManager: GitRepositoryManaging,
        promptRepository: PromptStreamingRepository,
        modelSelectionStore: ModelSelectionStore,
        mcpToolsStore: MCPToolsStore,
        profileViewModel: ProfileViewModel,
        projectCreationService: ProjectCreationService,
        chatViewModelProvider: ChatViewModelProvider
    ) {
        self.shellViewModel = shellViewModel
        self.modelRepository = modelRepository
        self.controlCenterResolver = controlCenterResolver
        self.controlCenterRuntimeManager = controlCenterRuntimeManager
        self.gitRepositoryManager = gitRepositoryManager
        self.promptRepository = promptRepository
        self.modelSelectionStore = modelSelectionStore
        self.mcpToolsStore = mcpToolsStore
        self.profileViewModel = profileViewModel
        self.projectCreationService = projectCreationService
        self.chatViewModelProvider = chatViewModelProvider
    }

    func chatViewModel(for chat: ChatThreadRef, project: ProjectRef) -> ChatViewModel {
        chatViewModelProvider.viewModel(for: chat, project: project)
    }
}
