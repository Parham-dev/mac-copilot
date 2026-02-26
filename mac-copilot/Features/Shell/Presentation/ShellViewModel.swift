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
    @Published private(set) var projectDeletionError: String?

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

    func deleteChat(chatID: ChatThreadRef.ID, in projectID: ProjectRef.ID) {
        let updatedChats = workspaceCoordinator.deleteChat(projectID: projectID, chatID: chatID)
        let replacementSelection: SidebarItem?
        if selectedItem == .chat(projectID, chatID) {
            if let replacement = updatedChats.first {
                replacementSelection = .chat(projectID, replacement.id)
            } else {
                replacementSelection = nil
            }
        } else {
            replacementSelection = selectedItem
        }

        selectedItem = replacementSelection
        projectChats[projectID] = updatedChats
    }

    func clearChatCreationError() {
        chatCreationError = nil
    }

    func clearProjectDeletionError() {
        projectDeletionError = nil
    }

    @discardableResult
    func addProject(name: String, localPath: String) throws -> ProjectRef {
        let created = try workspaceCoordinator.createProjectWithDefaultChat(name: name, localPath: localPath)
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

    func updateChatTitle(chatID: ChatThreadRef.ID, title: String) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { return }

        for projectID in projectChats.keys {
            guard var chats = projectChats[projectID],
                  let index = chats.firstIndex(where: { $0.id == chatID })
            else {
                continue
            }

            chats[index].title = normalizedTitle
            projectChats[projectID] = chats
            return
        }
    }

    func deleteProject(projectID: ProjectRef.ID) {
        let existed = projects.contains(where: { $0.id == projectID })
        guard existed else {
            projectDeletionError = "Project not found."
            return
        }

        let bootstrap = workspaceCoordinator.deleteProject(projectID: projectID)
        projects = bootstrap.projects
        projectChats = bootstrap.projectChats
        expandedProjectIDs = bootstrap.expandedProjectIDs
        activeProjectID = bootstrap.activeProjectID
        selectedItem = bootstrap.selectedItem
        projectDeletionError = nil
    }
}
