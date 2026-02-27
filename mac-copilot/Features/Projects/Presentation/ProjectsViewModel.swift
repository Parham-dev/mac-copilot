import Foundation
import Combine

/// Feature-owned navigation and workspace state for the Projects feature.
///
/// Extracted from the old `ShellViewModel` which used to be a god object.
/// The shell now treats this feature's selection opaquely as `AnyHashable`.
@MainActor
final class ProjectsViewModel: ObservableObject {

    // MARK: - Sidebar selection

    /// The item currently selected inside the Projects feature sidebar.
    enum SidebarItem: Hashable {
        case chat(ProjectRef.ID, ChatThreadRef.ID)
    }

    // MARK: - Published state

    @Published private(set) var projects: [ProjectRef]
    @Published private(set) var projectChats: [ProjectRef.ID: [ChatThreadRef]]
    @Published private(set) var expandedProjectIDs: Set<ProjectRef.ID>
    @Published var selectedItem: SidebarItem?
    @Published var activeProjectID: ProjectRef.ID?
    @Published private(set) var workspaceLoadError: String?
    @Published private(set) var chatCreationError: String?
    @Published private(set) var chatDeletionError: String?
    @Published private(set) var projectDeletionError: String?

    // MARK: - Private

    private let workspaceCoordinator: ProjectsWorkspaceCoordinator

    // MARK: - Init

    init(projectRepository: ProjectRepository, chatRepository: ChatRepository) {
        let coordinator = ProjectsWorkspaceCoordinator(
            projectRepository: projectRepository,
            chatRepository: chatRepository
        )
        let bootstrap = coordinator.makeBootstrapState()

        self.workspaceCoordinator = coordinator
        self.projects = bootstrap.projects
        self.projectChats = bootstrap.projectChats
        self.expandedProjectIDs = bootstrap.expandedProjectIDs
        self.activeProjectID = bootstrap.activeProjectID
        self.selectedItem = bootstrap.selectedItem
        self.workspaceLoadError = bootstrap.loadErrorMessage
    }

    // MARK: - Accessors

    var activeProject: ProjectRef? {
        guard let activeProjectID else { return nil }
        return projects.first(where: { $0.id == activeProjectID })
    }

    func project(for projectID: ProjectRef.ID) -> ProjectRef? {
        projects.first(where: { $0.id == projectID })
    }

    func chats(for projectID: ProjectRef.ID) -> [ChatThreadRef] {
        projectChats[projectID] ?? []
    }

    func chat(for chatID: ChatThreadRef.ID, in projectID: ProjectRef.ID) -> ChatThreadRef? {
        projectChats[projectID]?.first(where: { $0.id == chatID })
    }

    func isProjectExpanded(_ projectID: ProjectRef.ID) -> Bool {
        expandedProjectIDs.contains(projectID)
    }

    // MARK: - Navigation

    func setProjectExpanded(_ projectID: ProjectRef.ID, isExpanded: Bool) {
        if isExpanded {
            expandedProjectIDs.insert(projectID)
        } else {
            expandedProjectIDs.remove(projectID)
        }
    }

    func selectProject(_ projectID: ProjectRef.ID) {
        activeProjectID = projectID
        expandedProjectIDs.insert(projectID)
    }

    func didSelectItem(_ item: SidebarItem?) {
        guard let item else { return }
        switch item {
        case .chat(let projectID, _):
            activeProjectID = projectID
            expandedProjectIDs.insert(projectID)
        }
    }

    // MARK: - Chat CRUD

    func createChatInActiveProject() {
        guard let activeProjectID else {
            chatCreationError = "Select a project before creating a new chat."
            return
        }
        createChat(in: activeProjectID)
    }

    func createChat(in projectID: ProjectRef.ID) {
        let existing = projectChats[projectID] ?? []

        do {
            let created = try workspaceCoordinator.createChat(
                projectID: projectID,
                existingCount: existing.count
            )
            projectChats[projectID, default: []].append(created)
            expandedProjectIDs.insert(projectID)
            activeProjectID = projectID
            selectedItem = .chat(projectID, created.id)
            chatCreationError = nil
        } catch {
            chatCreationError = UserFacingErrorMapper.message(
                error, fallback: "Could not create chat right now."
            )
        }
    }

    func deleteChat(chatID: ChatThreadRef.ID, in projectID: ProjectRef.ID) {
        let updatedChats: [ChatThreadRef]
        do {
            updatedChats = try workspaceCoordinator.deleteChat(
                projectID: projectID,
                chatID: chatID
            )
        } catch {
            chatDeletionError = UserFacingErrorMapper.message(
                error, fallback: "Could not delete chat right now."
            )
            return
        }

        let replacementSelection: SidebarItem?
        if selectedItem == .chat(projectID, chatID) {
            replacementSelection = updatedChats.first.map { .chat(projectID, $0.id) }
        } else {
            replacementSelection = selectedItem
        }

        selectedItem = replacementSelection
        projectChats[projectID] = updatedChats
        chatDeletionError = nil
    }

    // MARK: - Project CRUD

    @discardableResult
    func addProject(name: String, localPath: String) throws -> ProjectRef {
        let created = try workspaceCoordinator.createProjectWithDefaultChat(
            name: name,
            localPath: localPath
        )
        let project = created.project
        projects.append(project)

        let defaultChat = created.defaultChat
        projectChats[project.id] = [defaultChat]
        expandedProjectIDs.insert(project.id)
        activeProjectID = project.id
        selectedItem = .chat(project.id, defaultChat.id)

        return project
    }

    func deleteProject(projectID: ProjectRef.ID) {
        guard projects.contains(where: { $0.id == projectID }) else {
            projectDeletionError = "Project not found."
            return
        }

        let bootstrap: ProjectsWorkspaceCoordinator.BootstrapState
        do {
            bootstrap = try workspaceCoordinator.deleteProject(projectID: projectID)
        } catch {
            projectDeletionError = UserFacingErrorMapper.message(
                error, fallback: "Could not delete project right now."
            )
            return
        }

        projects = bootstrap.projects
        projectChats = bootstrap.projectChats
        expandedProjectIDs = bootstrap.expandedProjectIDs
        activeProjectID = bootstrap.activeProjectID
        selectedItem = bootstrap.selectedItem
        workspaceLoadError = bootstrap.loadErrorMessage
        projectDeletionError = nil
    }

    // MARK: - Title updates

    func updateChatTitle(chatID: ChatThreadRef.ID, title: String) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { return }

        for projectID in projectChats.keys {
            guard var chats = projectChats[projectID],
                  let index = chats.firstIndex(where: { $0.id == chatID })
            else { continue }

            chats[index].title = normalizedTitle
            projectChats[projectID] = chats
            return
        }
    }

    // MARK: - Error dismissal

    func clearWorkspaceLoadError() { workspaceLoadError = nil }
    func clearChatCreationError() { chatCreationError = nil }
    func clearChatDeletionError() { chatDeletionError = nil }
    func clearProjectDeletionError() { projectDeletionError = nil }
}
