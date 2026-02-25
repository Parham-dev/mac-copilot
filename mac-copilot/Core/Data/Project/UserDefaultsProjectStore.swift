import Foundation

@MainActor
final class UserDefaultsProjectStore: ProjectStore {
    private let defaults: UserDefaults
    private let key = "copilotforge.projects"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadProjects() -> [ProjectRef] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        return (try? JSONDecoder().decode([ProjectRef].self, from: data)) ?? []
    }

    func saveProjects(_ projects: [ProjectRef]) {
        guard let encoded = try? JSONEncoder().encode(projects) else {
            return
        }
        defaults.set(encoded, forKey: key)
    }
}
