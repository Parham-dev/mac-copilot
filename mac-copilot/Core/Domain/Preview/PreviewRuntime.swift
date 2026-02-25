import Foundation

struct PreviewCommand {
    let executable: String
    let arguments: [String]
}

enum PreviewRuntimeMode {
    case directOpen(target: URL)
    case managedServer(
        install: PreviewCommand?,
        start: PreviewCommand,
        healthCheckURL: URL,
        openURL: URL,
        bootTimeoutSeconds: TimeInterval,
        environment: [String: String]
    )
}

struct PreviewRuntimePlan {
    let adapterID: String
    let adapterName: String
    let workingDirectory: URL
    let mode: PreviewRuntimeMode
}

protocol PreviewRuntimeAdapter {
    var id: String { get }
    var displayName: String { get }

    func canHandle(project: ProjectRef, utilities: PreviewRuntimeUtilities) -> Bool
    func makePlan(project: ProjectRef, utilities: PreviewRuntimeUtilities) throws -> PreviewRuntimePlan
}

enum PreviewRuntimeState: Equatable {
    case idle
    case installing
    case starting
    case running
    case failed(String)
}