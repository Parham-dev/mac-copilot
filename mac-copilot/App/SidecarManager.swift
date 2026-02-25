import Foundation

final class SidecarManager {
    static let shared = SidecarManager()

    private var process: Process?

    private init() {}

    func startIfNeeded() {
        guard process == nil else { return }

        guard let scriptURL = Bundle.main.url(forResource: "index", withExtension: "js", subdirectory: "sidecar") else {
            NSLog("[CopilotForge] sidecar/index.js not found in app bundle resources")
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

    func stop() {
        process?.terminate()
        process = nil
    }

    private func resolveNodeExecutable() -> URL? {
        if let bundled = Bundle.main.url(forResource: "node", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        let fallbacks = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
        ]

        for path in fallbacks where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        return nil
    }
}
