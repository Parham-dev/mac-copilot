import Foundation

@MainActor
final class ShellWorkspaceCoordinator {
    enum CoordinatorError: LocalizedError {
        case bootstrapLoadFailed(String)
        case chatCreationFailed
        case projectCreationFailed(String)
        case chatDeletionFailed(String)
        case projectDeletionFailed(String)

        var errorDescription: String? {
            switch self {
            case .bootstrapLoadFailed(let message):
                return message
            case .chatCreationFailed:
                return "Could not create chat thread. Please try again."
            case .projectCreationFailed(let message):
                return message
            case .chatDeletionFailed(let message):
                return message
            case .projectDeletionFailed(let message):
                return message
            }
        }
    }

    struct BootstrapState {
        let projects: [ProjectRef]
        let projectChats: [ProjectRef.ID: [ChatThreadRef]]
        let expandedProjectIDs: Set<ProjectRef.ID>
        let activeProjectID: ProjectRef.ID?
        let selectedItem: ShellViewModel.SidebarItem?
        let loadErrorMessage: String?
    }

    private let projectRepository: ProjectRepository
    private let chatRepository: ChatRepository

    init(projectRepository: ProjectRepository, chatRepository: ChatRepository) {
        self.projectRepository = projectRepository
        self.chatRepository = chatRepository
    }

    private func userFacingWorkspaceLoadMessage(_ error: Error) -> String {
        "Some local workspace data could not be loaded."
    }

    func makeBootstrapState() -> BootstrapState {
        let projects: [ProjectRef]
        do {
            projects = try projectRepository.fetchProjects()
        } catch {
            NSLog("[CopilotForge][Workspace] project bootstrap load failed: %@", error.localizedDescription)
            return BootstrapState(
                projects: [],
                projectChats: [:],
                expandedProjectIDs: [],
                activeProjectID: nil,
                selectedItem: nil,
                loadErrorMessage: userFacingWorkspaceLoadMessage(error)
            )
        }

        var projectChats: [ProjectRef.ID: [ChatThreadRef]] = [:]
        var loadErrorMessage: String?
        for project in projects {
            var chats: [ChatThreadRef]
            do {
                chats = try chatRepository.fetchChats(projectID: project.id)
            } catch {
                NSLog("[CopilotForge][Workspace] project chat load failed for %@: %@", project.name, error.localizedDescription)
                chats = []
                if loadErrorMessage == nil {
                    loadErrorMessage = userFacingWorkspaceLoadMessage(error)
                }
            }

            if chats.isEmpty {
                do {
                    chats = [try chatRepository.createChat(projectID: project.id, title: "General")]
                } catch {
                    NSLog("[CopilotForge][Workspace] bootstrap default chat create failed: %@", error.localizedDescription)
                    chats = []
                }
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
            selectedItem: selectedItem,
            loadErrorMessage: loadErrorMessage
        )
    }

    func createChat(projectID: UUID, existingCount: Int) throws -> ChatThreadRef {
        let title = "Chat \(existingCount + 1)"
        let created = try chatRepository.createChat(projectID: projectID, title: title)
        let persisted = try chatRepository.fetchChats(projectID: projectID)

        guard persisted.contains(where: { $0.id == created.id }) else {
            throw CoordinatorError.chatCreationFailed
        }

        return created
    }

    func createProjectWithDefaultChat(name: String, localPath: String) throws -> (project: ProjectRef, defaultChat: ChatThreadRef) {
        let project: ProjectRef
        do {
            project = try projectRepository.createProject(name: name, localPath: localPath)
        } catch {
            throw CoordinatorError.projectCreationFailed(error.localizedDescription)
        }

        let defaultChat = try chatRepository.createChat(projectID: project.id, title: "General")
        return (project, defaultChat)
    }

    func deleteChat(projectID: UUID, chatID: UUID) throws -> [ChatThreadRef] {
        do {
            try chatRepository.deleteChat(chatID: chatID)
        } catch {
            throw CoordinatorError.chatDeletionFailed(error.localizedDescription)
        }

        do {
            return try chatRepository.fetchChats(projectID: projectID)
        } catch {
            throw CoordinatorError.chatDeletionFailed(error.localizedDescription)
        }
    }

    func deleteProject(projectID: UUID) throws -> BootstrapState {
        do {
            try projectRepository.deleteProject(projectID: projectID)
        } catch {
            throw CoordinatorError.projectDeletionFailed(error.localizedDescription)
        }
        return makeBootstrapState()
    }
}
