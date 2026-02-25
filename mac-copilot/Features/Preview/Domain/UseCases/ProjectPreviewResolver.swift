import Foundation

struct ProjectPreviewResolver {
    private let adapters: [any ProjectPreviewAdapter]

    init(adapters: [any ProjectPreviewAdapter]) {
        self.adapters = adapters
    }

    func resolve(for project: ProjectRef) -> PreviewResolution {
        for adapter in adapters {
            if let launch = adapter.makeLaunch(for: project) {
                return .ready(launch)
            }
        }

        return .unavailable(message: "No preview adapter matched this project yet.")
    }
}
