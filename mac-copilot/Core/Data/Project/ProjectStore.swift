import Foundation

@MainActor
protocol ProjectStore {
    func loadProjects() -> [ProjectRef]
    func saveProjects(_ projects: [ProjectRef])
}
