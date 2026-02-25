import Foundation
import Combine

@MainActor
final class ShellViewModel: ObservableObject {
    enum SidebarItem: Hashable {
        case profile
        case chat(ProjectRef.ID, String)
    }

    enum ContextTab: String, CaseIterable, Identifiable {
        case preview
        case git

        var id: String { rawValue }
    }

    @Published private(set) var projects: [ProjectRef]
    @Published private(set) var projectChats: [ProjectRef.ID: [String]]
    @Published private(set) var expandedProjectIDs: Set<ProjectRef.ID>
    @Published var selectedItem: SidebarItem?
    @Published var selectedContextTab: ContextTab = .preview
    @Published var activeProjectID: ProjectRef.ID?

    private let projectStore: ProjectStore

    init(projectStore: ProjectStore) {
        let loadedProjects = projectStore.loadProjects()
        var seededChats: [ProjectRef.ID: [String]] = [:]
        for project in loadedProjects {
            seededChats[project.id] = ["General"]
        }

        self.projectStore = projectStore
        self.projects = loadedProjects
        self.projectChats = seededChats
        self.expandedProjectIDs = Set(loadedProjects.map(\.id))
        self.activeProjectID = loadedProjects.first?.id

        if let firstProject = loadedProjects.first,
           let firstChat = seededChats[firstProject.id]?.first {
            self.selectedItem = .chat(firstProject.id, firstChat)
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

    func chats(for projectID: ProjectRef.ID) -> [String] {
        projectChats[projectID] ?? []
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
        projectChats[projectID, default: []].append(title)
        expandedProjectIDs.insert(projectID)
        activeProjectID = projectID
        selectedItem = .chat(projectID, title)
    }

    @discardableResult
    func addProject(name: String, localPath: String) -> ProjectRef {
        let project = ProjectRef(name: name, localPath: localPath)
        projects.append(project)
        projectStore.saveProjects(projects)

        projectChats[project.id] = ["General"]
        expandedProjectIDs.insert(project.id)
        activeProjectID = project.id
        selectedItem = .chat(project.id, "General")

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
