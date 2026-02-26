import Foundation

@MainActor
protocol ProjectRepository {
    func fetchProjects() -> [ProjectRef]

    @discardableResult
    func createProject(name: String, localPath: String) throws -> ProjectRef

    func deleteProject(projectID: UUID) throws
}