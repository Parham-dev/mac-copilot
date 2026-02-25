import Foundation

@MainActor
protocol ProjectRepository {
    func fetchProjects() -> [ProjectRef]

    @discardableResult
    func createProject(name: String, localPath: String) -> ProjectRef
}