import Foundation

@MainActor
final class InMemoryProjectStore: ProjectStore {
    private var projects: [ProjectRef]

    init(seedProjects: [ProjectRef]? = nil) {
        if let seedProjects {
            self.projects = seedProjects
            return
        }

        self.projects = []
    }

    func loadProjects() -> [ProjectRef] {
        projects
    }

    func saveProjects(_ projects: [ProjectRef]) {
        self.projects = projects
    }
}
