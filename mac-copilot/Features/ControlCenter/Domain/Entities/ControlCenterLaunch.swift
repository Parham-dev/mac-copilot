import Foundation

enum ControlCenterLaunchTarget {
    case file(URL)
    case web(URL)
}

struct ControlCenterLaunch {
    let adapterID: String
    let adapterName: String
    let summary: String
    let detail: String
    let actionTitle: String
    let target: ControlCenterLaunchTarget
}

enum ControlCenterResolution {
    case ready(ControlCenterLaunch)
    case unavailable(message: String)
}
