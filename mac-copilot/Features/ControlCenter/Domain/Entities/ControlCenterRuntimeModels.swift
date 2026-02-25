import Foundation

struct ControlCenterCommand {
    let executable: String
    let arguments: [String]
}

enum ControlCenterRuntimeMode {
    case directOpen(target: URL)
    case managedServer(
        install: ControlCenterCommand?,
        start: ControlCenterCommand,
        healthCheckURL: URL,
        openURL: URL,
        bootTimeoutSeconds: TimeInterval,
        environment: [String: String]
    )
}

struct ControlCenterRuntimePlan {
    let adapterID: String
    let adapterName: String
    let workingDirectory: URL
    let mode: ControlCenterRuntimeMode
}

enum ControlCenterRuntimeState: Equatable {
    case idle
    case installing
    case starting
    case running
    case failed(String)
}
