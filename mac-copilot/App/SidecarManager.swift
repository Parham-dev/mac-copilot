import Foundation

final class SidecarManager {
    static let shared = SidecarManager()

    private var process: Process?

    private init() {}

    func startIfNeeded() {
        guard process == nil else { return }

        guard let scriptURL = resolveSidecarScriptURL() else {
            NSLog("[CopilotForge] sidecar/index.js not found in app bundle resources or local source tree")
            return
        }

        guard let nodeExecutable = resolveNodeExecutable() else {
            NSLog("[CopilotForge] Node executable not found (expected bundled node or /opt/homebrew/bin/node or /usr/local/bin/node)")
            return
        }

        let process = Process()
        process.executableURL = nodeExecutable
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()
        process.environment = ProcessInfo.processInfo.environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        process.terminationHandler = { [weak self] _ in
            self?.process = nil
        }

        do {
            try process.run()
            self.process = process
            NSLog("[CopilotForge] Sidecar started at %@", scriptURL.path)
        } catch {
            NSLog("[CopilotForge] Failed to start sidecar: %@", error.localizedDescription)
        }
    }

    private func resolveSidecarScriptURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "index", withExtension: "js", subdirectory: "sidecar") {
            return bundled
        }

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectAppFolder = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRootFolder = projectAppFolder.deletingLastPathComponent()

        let candidatePaths = [
            projectRootFolder
                .appendingPathComponent("sidecar", isDirectory: true)
                .appendingPathComponent("index.js", isDirectory: false),
            projectAppFolder
                .appendingPathComponent("sidecar", isDirectory: true)
                .appendingPathComponent("index.js", isDirectory: false),
        ]

        for candidate in candidatePaths where FileManager.default.fileExists(atPath: candidate.path) {
            NSLog("[CopilotForge] Using local sidecar source at %@", candidate.path)
            return candidate
        }

        return nil
    }

    func stop() {
        process?.terminate()
        process = nil
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

        if let resolvedFromPath = resolveNodeFromEnvironmentPATH() {
            return resolvedFromPath
        }

        return nil
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
}
