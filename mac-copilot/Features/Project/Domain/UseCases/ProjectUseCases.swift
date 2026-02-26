import Foundation

@MainActor
struct FetchProjectsUseCase {
    private let repository: ProjectRepository

    init(repository: ProjectRepository) {
        self.repository = repository
    }

    func execute() -> [ProjectRef] {
        repository.fetchProjects()
    }
}

@MainActor
struct CreateProjectUseCase {
    private let repository: ProjectRepository

    init(repository: ProjectRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(name: String, localPath: String) throws -> ProjectRef {
        try repository.createProject(name: name, localPath: localPath)
    }
}

@MainActor
struct DeleteProjectUseCase {
    private let repository: ProjectRepository

    init(repository: ProjectRepository) {
        self.repository = repository
    }

    func execute(projectID: UUID) throws {
        try repository.deleteProject(projectID: projectID)
    }
}
