import Foundation

struct SidecarStartupConfig {
    let scriptURL: URL
    let nodeExecutable: URL
    let nodeVersion: String
}

enum SidecarPreflightError: LocalizedError {
    case missingSidecarScript
    case missingNode
    case unsupportedNodeVersion(found: String)
    case unsupportedNodeRuntime(executable: String)
    case missingDependencies(path: String)

    var errorDescription: String? {
        switch self {
        case .missingSidecarScript:
            return "sidecar/dist/index.js not found in app bundle resources or local source tree"
        case .missingNode:
            return "Compatible Node executable not found (requires node:sqlite support; Node 22+). Release builds require bundled Node in app resources."
        case .unsupportedNodeVersion(let found):
            return "Node version \(found) is unsupported. Node 22+ is required"
        case .unsupportedNodeRuntime(let executable):
            return "Node runtime at \(executable) is missing required built-in modules (node:sqlite). Install/use Node 22+ and restart CopilotForge."
        case .missingDependencies(let path):
            return "Sidecar dependencies missing at \(path). Run npm install in sidecar directory"
        }
    }
}
