import Foundation

struct ProjectControlCenterResolver {
    private let adapters: [any ProjectControlCenterAdapter]

    init(adapters: [any ProjectControlCenterAdapter]) {
        self.adapters = adapters
    }

    func resolve(for project: ProjectRef) -> ControlCenterResolution {
        for adapter in adapters {
            if let launch = adapter.makeLaunch(for: project) {
                return .ready(launch)
            }
        }

        return .unavailable(message: "No control center adapter matched this project yet.")
    }
}
