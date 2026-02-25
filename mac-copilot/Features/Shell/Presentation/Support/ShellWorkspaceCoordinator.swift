import Foundation

@MainActor
final class ShellWorkspaceCoordinator {
    struct BootstrapState {
        let projects: [ProjectRef]
        let projectChats: [ProjectRef.ID: [ChatThreadRef]]
        let expandedProjectIDs: Set<ProjectRef.ID>
        let activeProjectID: ProjectRef.ID?
        let selectedItem: ShellViewModel.SidebarItem?
    }

    private let projectRepository: ProjectRepository
    private let chatRepository: ChatRepository

    init(projectRepository: ProjectRepository, chatRepository: ChatRepository) {
        self.projectRepository = projectRepository
        self.chatRepository = chatRepository
    }

    func makeBootstrapState() -> BootstrapState {
        let projects = projectRepository.fetchProjects()

        var projectChats: [ProjectRef.ID: [ChatThreadRef]] = [:]
        for project in projects {
            var chats = chatRepository.fetchChats(projectID: project.id)
            if chats.isEmpty {
                chats = [chatRepository.createChat(projectID: project.id, title: "General")]
            }
            projectChats[project.id] = chats
        }

        let activeProjectID = projects.first?.id
        let selectedItem: ShellViewModel.SidebarItem?
        if let firstProject = projects.first,
           let firstChat = projectChats[firstProject.id]?.first {
            selectedItem = .chat(firstProject.id, firstChat.id)
        } else {
            selectedItem = nil
        }

        return BootstrapState(
            projects: projects,
            projectChats: projectChats,
            expandedProjectIDs: Set(projects.map(\.id)),
            activeProjectID: activeProjectID,
            selectedItem: selectedItem
        )
    }

    func createChat(projectID: UUID, existingCount: Int) -> ChatThreadRef {
        let title = "Chat \(existingCount + 1)"
        return chatRepository.createChat(projectID: projectID, title: title)
    }

    func createProjectWithDefaultChat(name: String, localPath: String) -> (project: ProjectRef, defaultChat: ChatThreadRef) {
        let project = projectRepository.createProject(name: name, localPath: localPath)
        let defaultChat = chatRepository.createChat(projectID: project.id, title: "General")
        return (project, defaultChat)
    }
}
