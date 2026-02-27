import Foundation
import Combine

@MainActor
protocol FeatureSelectionSyncing: AnyObject {
    func selection(for featureID: String) -> AnyHashable?
    func setSelection(_ selection: AnyHashable?, for featureID: String)
}

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

    // MARK: - Shell bridge

    func handleShellListSelectionChange(featureID: String, newSelection: AnyHashable?) {
        guard featureID == ProjectsFeatureModule.featureID else { return }
        let decoded = newSelection as? ProjectsViewModel.SidebarItem
        guard projectsViewModel.selectedItem != decoded else { return }
        projectsViewModel.selectedItem = decoded
        projectsViewModel.didSelectItem(decoded)
    }

    func syncSelectionToShell(_ newItem: ProjectsViewModel.SidebarItem?, selectionSync: FeatureSelectionSyncing) {
        let featureID = ProjectsFeatureModule.featureID
        let current = selectionSync.selection(for: featureID)
        let newHashable = newItem.map { AnyHashable($0) }
        guard current != newHashable else { return }
        selectionSync.setSelection(newHashable, for: featureID)
    }

    func handleChatTitleDidUpdate(chatID: UUID, title: String) {
        projectsViewModel.updateChatTitle(chatID: chatID, title: title)
    }

    var activeWarningMessage: String? {
        if let err = projectsViewModel.workspaceLoadError, !err.isEmpty { return err }
        if let err = projectsViewModel.chatCreationError, !err.isEmpty { return err }
        if let err = projectsViewModel.chatDeletionError, !err.isEmpty { return err }
        if let err = projectsViewModel.projectDeletionError, !err.isEmpty { return err }
        return nil
    }

    @discardableResult
    func dismissActiveWarning() -> Bool {
        if projectsViewModel.workspaceLoadError != nil { projectsViewModel.clearWorkspaceLoadError(); return true }
        if projectsViewModel.chatCreationError != nil { projectsViewModel.clearChatCreationError(); return true }
        if projectsViewModel.chatDeletionError != nil { projectsViewModel.clearChatDeletionError(); return true }
        if projectsViewModel.projectDeletionError != nil { projectsViewModel.clearProjectDeletionError(); return true }
        return false
    }
}
