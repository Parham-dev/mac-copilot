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
            return "sidecar/index.js not found in app bundle resources or local source tree"
        case .missingNode:
            return "Node executable not found (expected bundled node or /opt/homebrew/bin/node or /usr/local/bin/node)"
        case .unsupportedNodeVersion(let found):
            return "Node version \(found) is unsupported. Node 20+ is required"
        case .unsupportedNodeRuntime(let executable):
            return "Node runtime at \(executable) is missing required built-in modules (node:sqlite). Install/use a newer Node runtime."
        case .missingDependencies(let path):
            return "Sidecar dependencies missing at \(path). Run npm install in sidecar directory"
        }
    }
}
