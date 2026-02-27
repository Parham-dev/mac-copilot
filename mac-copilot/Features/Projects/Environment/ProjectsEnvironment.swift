import Foundation
import Combine

/// Self-contained environment for the Projects feature.
///
/// Owns all dependencies required by the Projects sidebar, chat detail pane,
/// context pane, control centre, and git panel.
///
/// Injected as an `@EnvironmentObject` into `ProjectsSidebarSection` and
/// `ProjectsDetailView`.
@MainActor
final class ProjectsEnvironment: ObservableObject {

    // MARK: - Navigation / workspace state

    let projectsViewModel: ProjectsViewModel

    // MARK: - Services

    let projectCreationService: ProjectCreationService
    let appUpdateManager: any AppUpdateManaging

    // MARK: - Chat

    let modelRepository: ModelListingRepository
    let promptRepository: PromptStreamingRepository
    let modelSelectionStore: ModelSelectionStore
    let nativeToolsStore: NativeToolsStore
    let mcpToolsStore: MCPToolsStore
    let chatEventsStore: ChatEventsStore

    // MARK: - Context pane / control centre / git

    let controlCenterResolver: ProjectControlCenterResolver
    let controlCenterRuntimeManager: ControlCenterRuntimeManager
    let gitRepositoryManager: GitRepositoryManaging

    // MARK: - Private providers

    private let chatViewModelProvider: ChatViewModelProvider
    private let contextPaneViewModelProvider: ContextPaneViewModelProvider

    // MARK: - Init

    init(
        projectsViewModel: ProjectsViewModel,
        projectCreationService: ProjectCreationService,
        appUpdateManager: any AppUpdateManaging,
        chatViewModelProvider: ChatViewModelProvider,
        contextPaneViewModelProvider: ContextPaneViewModelProvider,
        controlCenterResolver: ProjectControlCenterResolver,
        controlCenterRuntimeManager: ControlCenterRuntimeManager,
        gitRepositoryManager: GitRepositoryManaging,
        modelSelectionStore: ModelSelectionStore,
        nativeToolsStore: NativeToolsStore,
        mcpToolsStore: MCPToolsStore,
        chatEventsStore: ChatEventsStore,
        modelRepository: ModelListingRepository,
        promptRepository: PromptStreamingRepository
    ) {
        self.projectsViewModel = projectsViewModel
        self.projectCreationService = projectCreationService
        self.appUpdateManager = appUpdateManager
        self.chatViewModelProvider = chatViewModelProvider
        self.contextPaneViewModelProvider = contextPaneViewModelProvider
        self.controlCenterResolver = controlCenterResolver
        self.controlCenterRuntimeManager = controlCenterRuntimeManager
        self.gitRepositoryManager = gitRepositoryManager
        self.modelSelectionStore = modelSelectionStore
        self.nativeToolsStore = nativeToolsStore
        self.mcpToolsStore = mcpToolsStore
        self.chatEventsStore = chatEventsStore
        self.modelRepository = modelRepository
        self.promptRepository = promptRepository
    }

    // MARK: - Factory helpers

    func chatViewModel(for chat: ChatThreadRef, project: ProjectRef) -> ChatViewModel {
        chatViewModelProvider.viewModel(for: chat, project: project)
    }

    func contextPaneViewModel(for projectID: UUID) -> ContextPaneViewModel {
        contextPaneViewModelProvider.viewModel(for: projectID)
    }

    func evictContextPaneViewModel(for projectID: UUID) {
        contextPaneViewModelProvider.evict(projectID: projectID)
    }
}
