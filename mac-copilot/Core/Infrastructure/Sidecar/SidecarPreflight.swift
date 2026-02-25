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
    case missingDependencies(path: String)

    var errorDescription: String? {
        switch self {
        case .missingSidecarScript:
            return "sidecar/index.js not found in app bundle resources or local source tree"
        case .missingNode:
            return "Node executable not found (expected bundled node or /opt/homebrew/bin/node or /usr/local/bin/node)"
        case .unsupportedNodeVersion(let found):
            return "Node version \(found) is unsupported. Node 20+ is required"
        case .missingDependencies(let path):
            return "Sidecar dependencies missing at \(path). Run npm install in sidecar directory"
        }
    }
}

final class SidecarPreflight {
    private let minimumNodeMajorVersion: Int

    init(minimumNodeMajorVersion: Int) {
        self.minimumNodeMajorVersion = minimumNodeMajorVersion
    }

    func check() throws -> SidecarStartupConfig {
        guard let scriptURL = resolveSidecarScriptURL() else {
            throw SidecarPreflightError.missingSidecarScript
        }

        guard let nodeExecutable = resolveNodeExecutable() else {
            throw SidecarPreflightError.missingNode
        }

        let nodeVersion = nodeVersionString(executable: nodeExecutable)
        guard isSupportedNodeVersion(nodeVersion) else {
            throw SidecarPreflightError.unsupportedNodeVersion(found: nodeVersion)
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

    private func resolveSidecarScriptURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "index", withExtension: "js", subdirectory: "sidecar") {
            return bundled
        }

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        var searchCursor = sourceFileURL.deletingLastPathComponent()

        for _ in 0 ..< 12 {
            let candidate = searchCursor
                .appendingPathComponent("sidecar", isDirectory: true)
                .appendingPathComponent("index.js", isDirectory: false)

            if FileManager.default.fileExists(atPath: candidate.path) {
                NSLog("[CopilotForge] Using local sidecar source at %@", candidate.path)
                return candidate
            }

            let parent = searchCursor.deletingLastPathComponent()
            if parent.path == searchCursor.path {
                break
            }
            searchCursor = parent
        }

        return nil
    }

    private func resolveNodeExecutable() -> URL? {
        if let override = ProcessInfo.processInfo.environment["COPILOTFORGE_NODE_PATH"],
           FileManager.default.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }

        if let bundled = Bundle.main.url(forResource: "node", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        let fallbacks = [
            "/opt/homebrew/bin/node",
            "/opt/homebrew/opt/node@20/bin/node",
            "/opt/homebrew/opt/node/bin/node",
            "/usr/local/bin/node",
            "/opt/local/bin/node",
        ]

        for path in fallbacks where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        return resolveNodeFromEnvironmentPATH()
    }

    private func resolveNodeFromEnvironmentPATH() -> URL? {
        guard let pathValue = ProcessInfo.processInfo.environment["PATH"], !pathValue.isEmpty else {
            return nil
        }

        let directories = pathValue
            .split(separator: ":")
            .map { String($0) }

        for directory in directories {
            let candidate = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent("node", isDirectory: false)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private func nodeVersionString(executable: URL) -> String {
        let output = runCommand(executable: executable.path, arguments: ["-v"])
        let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? "unknown" : version
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

    private func runCommand(executable: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
