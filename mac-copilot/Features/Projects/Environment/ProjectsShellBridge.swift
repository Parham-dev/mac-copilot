import Foundation
import Combine

@MainActor
protocol FeatureSelectionSyncing: AnyObject {
    func selection(for featureID: String) -> AnyHashable?
    func setSelection(_ selection: AnyHashable?, for featureID: String)
}

/// Shell-facing adapter for Projects feature interactions.
///
/// Keeps shell-specific orchestration out of `ProjectsEnvironment` so Shell can
/// depend on a smaller surface area.
@MainActor
final class ProjectsShellBridge: ObservableObject {
    let projectsViewModel: ProjectsViewModel

    private let appUpdateManager: any AppUpdateManaging
    private let chatEventsStore: ChatEventsStore

    init(
        projectsViewModel: ProjectsViewModel,
        appUpdateManager: any AppUpdateManaging,
        chatEventsStore: ChatEventsStore
    ) {
        self.projectsViewModel = projectsViewModel
        self.appUpdateManager = appUpdateManager
        self.chatEventsStore = chatEventsStore
    }

    var chatTitleDidUpdate: AnyPublisher<ChatTitleDidUpdateEvent, Never> {
        chatEventsStore.chatTitleDidUpdate
    }

    func checkForUpdates() throws {
        try appUpdateManager.checkForUpdates()
    }

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