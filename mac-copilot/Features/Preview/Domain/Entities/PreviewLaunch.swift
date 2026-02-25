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
