import Foundation
import Combine

@MainActor
final class ShellViewModel: ObservableObject {
    enum SidebarItem: Hashable {
        case profile
        case chat(ProjectRef.ID, ChatThreadRef.ID)
    }

    enum ContextTab: String, CaseIterable, Identifiable {
        case preview
        case git

        var id: String { rawValue }
    }

    @Published private(set) var projects: [ProjectRef]
    @Published private(set) var projectChats: [ProjectRef.ID: [ChatThreadRef]]
    @Published private(set) var expandedProjectIDs: Set<ProjectRef.ID>
    @Published var selectedItem: SidebarItem?
    @Published var selectedContextTab: ContextTab = .preview
    @Published var activeProjectID: ProjectRef.ID?

    private let projectRepository: ProjectRepository
    private let chatRepository: ChatRepository

    init(projectRepository: ProjectRepository, chatRepository: ChatRepository) {
        let loadedProjects = projectRepository.fetchProjects()
        var seededChats: [ProjectRef.ID: [ChatThreadRef]] = [:]
        for project in loadedProjects {
            var chats = chatRepository.fetchChats(projectID: project.id)
            if chats.isEmpty {
                chats = [chatRepository.createChat(projectID: project.id, title: "General")]
            }
            seededChats[project.id] = chats
        }

        self.projectRepository = projectRepository
        self.chatRepository = chatRepository
        self.projects = loadedProjects
        self.projectChats = seededChats
        self.expandedProjectIDs = Set(loadedProjects.map(\.id))
        self.activeProjectID = loadedProjects.first?.id

        if let firstProject = loadedProjects.first,
           let firstChat = seededChats[firstProject.id]?.first {
            self.selectedItem = .chat(firstProject.id, firstChat.id)
        } else {
            self.selectedItem = nil
        }
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
        guard let activeProjectID else { return }
        createChat(in: activeProjectID)
    }

    func createChat(in projectID: ProjectRef.ID) {
        let existing = projectChats[projectID] ?? []
        let title = "Chat \(existing.count + 1)"
        let created = chatRepository.createChat(projectID: projectID, title: title)
        projectChats[projectID, default: []].append(created)
        expandedProjectIDs.insert(projectID)
        activeProjectID = projectID
        selectedItem = .chat(projectID, created.id)
    }

    @discardableResult
    func addProject(name: String, localPath: String) -> ProjectRef {
        let project = projectRepository.createProject(name: name, localPath: localPath)
        projects.append(project)

        let defaultChat = chatRepository.createChat(projectID: project.id, title: "General")
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
