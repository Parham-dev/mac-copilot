import Foundation

struct SidecarProcessTermination {
    let reasonRawValue: Int
    let status: Int32
    let processIdentifier: Int32
    let intentional: Bool
}

final class SidecarProcessController {
    private let callbackQueue: DispatchQueue

    private var process: Process?
    private var outputPipe: Pipe?
    private var intentionallyTerminatedPIDs: Set<Int32> = []

    init(callbackQueue: DispatchQueue) {
        self.callbackQueue = callbackQueue
    }

    var isRunning: Bool {
        process?.isRunning == true
    }

    func hasStaleProcessHandle() -> Bool {
        guard let process else { return false }
        return !process.isRunning
    }

    func clearStaleProcessHandle() {
        guard hasStaleProcessHandle() else { return }
        cleanupHandles()
    }

    func start(
        nodeExecutable: URL,
        scriptURL: URL,
        outputHandler: @escaping (String) -> Void,
        terminationHandler: @escaping (SidecarProcessTermination) -> Void
    ) throws {
        let process = Process()
        process.executableURL = nodeExecutable
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()

        var environment = ProcessInfo.processInfo.environment
        environment["NODE_NO_WARNINGS"] = "1"
        if environment["COPILOTFORGE_REQUIRE_FETCH_MCP"] == nil {
            environment["COPILOTFORGE_REQUIRE_FETCH_MCP"] = "0"
        }
        if environment["COPILOTFORGE_ALLOW_NATIVE_FETCH_FALLBACK"] == nil {
            environment["COPILOTFORGE_ALLOW_NATIVE_FETCH_FALLBACK"] = "1"
        }
        if environment["COPILOTFORGE_FETCH_MCP_COMMAND"] == nil {
            let homeDirectory = NSHomeDirectory()
            let uvxPath = (homeDirectory as NSString).appendingPathComponent(".local/bin/uvx")
            if FileManager.default.fileExists(atPath: uvxPath) {
                environment["COPILOTFORGE_FETCH_MCP_COMMAND"] = uvxPath
            }
        }
        process.environment = environment

        let outputPipe = Pipe()
        self.outputPipe = outputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8)
            else {
                return
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            outputHandler(trimmed)
        }

        process.terminationHandler = { [weak self] terminated in
            guard let self else { return }

            self.callbackQueue.async {
                let pid = terminated.processIdentifier
                let intentional = self.intentionallyTerminatedPIDs.remove(pid) != nil
                self.cleanupHandles()

                terminationHandler(
                    SidecarProcessTermination(
                        reasonRawValue: terminated.terminationReason.rawValue,
                        status: terminated.terminationStatus,
                        processIdentifier: pid,
                        intentional: intentional
                    )
                )
            }
        }

        try process.run()
        self.process = process
    }

    func stop() {
        if let pid = process?.processIdentifier {
            intentionallyTerminatedPIDs.insert(pid)
        }
        process?.terminate()
        cleanupHandles()
    }

    private func cleanupHandles() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        process = nil
    }
}
