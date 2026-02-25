import Foundation

final class SidecarPreflight {
    private let minimumNodeMajorVersion: Int
    private let scriptResolver: SidecarScriptResolver
    private let nodeRuntimeResolver: SidecarNodeRuntimeResolver

    init(
        minimumNodeMajorVersion: Int,
        scriptResolver: SidecarScriptResolver = SidecarScriptResolver(),
        nodeRuntimeResolver: SidecarNodeRuntimeResolver = SidecarNodeRuntimeResolver()
    ) {
        self.minimumNodeMajorVersion = minimumNodeMajorVersion
        self.scriptResolver = scriptResolver
        self.nodeRuntimeResolver = nodeRuntimeResolver
    }

    func check() throws -> SidecarStartupConfig {
        guard let scriptURL = scriptResolver.resolveSidecarScriptURL() else {
            throw SidecarPreflightError.missingSidecarScript
        }

        guard let nodeExecutable = nodeRuntimeResolver.resolveNodeExecutable() else {
            throw SidecarPreflightError.missingNode
        }

        let nodeVersion = nodeRuntimeResolver.nodeVersionString(executable: nodeExecutable)
        guard isSupportedNodeVersion(nodeVersion) else {
            throw SidecarPreflightError.unsupportedNodeVersion(found: nodeVersion)
        }

        guard nodeRuntimeResolver.supportsRequiredBuiltins(executable: nodeExecutable) else {
            throw SidecarPreflightError.unsupportedNodeRuntime(executable: nodeExecutable.path)
        }

        if !isBundledSidecar(scriptURL) {
            let sidecarDirectory = scriptURL.deletingLastPathComponent()
            let sdkPackagePath = sidecarDirectory
                .appendingPathComponent("node_modules", isDirectory: true)
                .appendingPathComponent("@github", isDirectory: true)
                .appendingPathComponent("copilot-sdk", isDirectory: true)
                .path
            if !FileManager.default.fileExists(atPath: sdkPackagePath) {
                throw SidecarPreflightError.missingDependencies(path: sdkPackagePath)
            }
        }

        return SidecarStartupConfig(scriptURL: scriptURL, nodeExecutable: nodeExecutable, nodeVersion: nodeVersion)
    }

    private func isSupportedNodeVersion(_ versionString: String) -> Bool {
        let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "unknown" else {
            return false
        }
        let numeric = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let majorToken = numeric.split(separator: ".").first ?? "0"
        guard let major = Int(majorToken) else {
            return false
        }
        return major >= minimumNodeMajorVersion
    }

    private func isBundledSidecar(_ scriptURL: URL) -> Bool {
        let resourcesPath = Bundle.main.resourceURL?.path ?? ""
        guard !resourcesPath.isEmpty else { return false }
        return scriptURL.path.hasPrefix(resourcesPath)
    }
}
