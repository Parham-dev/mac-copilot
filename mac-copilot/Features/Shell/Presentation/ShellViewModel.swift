import Foundation
import Combine

@MainActor
final class ShellViewModel: ObservableObject {
    enum SidebarItem: Hashable {
        case profile
        case chat(ProjectRef.ID, ChatThreadRef.ID)
    }

    enum ContextTab: String, CaseIterable, Identifiable {
        case controlCenter
        case git

        var id: String { rawValue }
    }

    @Published private(set) var projects: [ProjectRef]
    @Published private(set) var projectChats: [ProjectRef.ID: [ChatThreadRef]]
    @Published private(set) var expandedProjectIDs: Set<ProjectRef.ID>
    @Published var selectedItem: SidebarItem?
    @Published var selectedContextTab: ContextTab = .controlCenter
    @Published var activeProjectID: ProjectRef.ID?
    @Published private(set) var chatCreationError: String?

    private let workspaceCoordinator: ShellWorkspaceCoordinator

    init(projectRepository: ProjectRepository, chatRepository: ChatRepository) {
        let coordinator = ShellWorkspaceCoordinator(projectRepository: projectRepository, chatRepository: chatRepository)
        let bootstrap = coordinator.makeBootstrapState()

        self.workspaceCoordinator = coordinator
        self.projects = bootstrap.projects
        self.projectChats = bootstrap.projectChats
        self.expandedProjectIDs = bootstrap.expandedProjectIDs
        self.activeProjectID = bootstrap.activeProjectID
        self.selectedItem = bootstrap.selectedItem
    }

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
            let created = try workspaceCoordinator.createChat(projectID: projectID, existingCount: existing.count)
            projectChats[projectID, default: []].append(created)
            expandedProjectIDs.insert(projectID)
            activeProjectID = projectID
            selectedItem = .chat(projectID, created.id)
            chatCreationError = nil
        } catch {
            chatCreationError = error.localizedDescription
        }
    }

    func clearChatCreationError() {
        chatCreationError = nil
    }

    @discardableResult
    func addProject(name: String, localPath: String) -> ProjectRef {
        let created = workspaceCoordinator.createProjectWithDefaultChat(name: name, localPath: localPath)
        let project = created.project
        projects.append(project)

        let defaultChat = created.defaultChat
        projectChats[project.id] = [defaultChat]
        expandedProjectIDs.insert(project.id)
        activeProjectID = project.id
        selectedItem = .chat(project.id, defaultChat.id)

        return project
    }

    func didSelectSidebarItem(_ item: SidebarItem?) {
        guard let item else { return }
        switch item {
        case .profile:
            break
        case .chat(let projectID, _):
            activeProjectID = projectID
            expandedProjectIDs.insert(projectID)
        }
    }
}
