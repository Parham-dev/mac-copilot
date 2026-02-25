import Foundation

enum PreviewLaunchTarget {
    case file(URL)
    case web(URL)
}

struct PreviewLaunch {
    let adapterID: String
    let adapterName: String
    let summary: String
    let detail: String
    let actionTitle: String
    let target: PreviewLaunchTarget
}

enum PreviewResolution {
    case ready(PreviewLaunch)
    case unavailable(message: String)
}

protocol ProjectPreviewAdapter {
    var id: String { get }
    var displayName: String { get }

    func makeLaunch(for project: ProjectRef) -> PreviewLaunch?
}

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