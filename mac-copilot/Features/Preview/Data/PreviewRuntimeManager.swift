import Foundation
import AppKit
import Combine

@MainActor
final class PreviewRuntimeManager: ObservableObject {
    @Published private(set) var state: PreviewRuntimeState = .idle
    @Published private(set) var adapterName: String?
    @Published private(set) var activeURL: URL?
    @Published private(set) var logs: [String] = []
    @Published private(set) var activeProjectID: UUID?

    private let adapters: [any PreviewRuntimeAdapter]
    private let utilities: PreviewRuntimeUtilities

    private var process: Process?
    private var outputPipe: Pipe?

    init(adapters: [any PreviewRuntimeAdapter], utilities: PreviewRuntimeUtilities = PreviewRuntimeUtilities()) {
        self.adapters = adapters
        self.utilities = utilities
    }

    var isBusy: Bool {
        switch state {
        case .installing, .starting:
            return true
        case .idle, .running, .failed:
            return false
        }
    }

    var isRunning: Bool {
        state == .running
    }

    func start(project: ProjectRef, autoOpen: Bool = true) {
        Task {
            await startInternal(project: project, autoOpen: autoOpen, isRefresh: false)
        }
    }

    func refresh(project: ProjectRef) {
        Task {
            await startInternal(project: project, autoOpen: true, isRefresh: true)
        }
    }

    func stop() {
        process?.terminate()
        cleanupProcessHandles()
        state = .idle
        appendLog("Stopped preview runtime")
    }

    func openInBrowser() {
        guard let activeURL else { return }
        NSWorkspace.shared.open(activeURL)
    }

    private func startInternal(project: ProjectRef, autoOpen: Bool, isRefresh: Bool) async {
        if isRefresh {
            appendLog("Refreshing preview for \(project.name)")
            stop()
        } else if activeProjectID != nil, activeProjectID != project.id {
            appendLog("Switching preview runtime to \(project.name)")
            stop()
        }

        activeProjectID = project.id
        activeURL = nil
        logs.removeAll(keepingCapacity: true)

        guard let adapter = adapters.first(where: { $0.canHandle(project: project) }) else {
            state = .failed("No preview adapter supports this project yet")
            appendLog("No adapter matched project")
            return
        }

        adapterName = adapter.displayName
        appendLog("Using adapter: \(adapter.displayName)")

        do {
            let plan = try adapter.makePlan(project: project)

            switch plan.mode {
            case .directOpen(let target):
                state = .running
                activeURL = target
                appendLog("Ready: \(target.absoluteString)")
                if autoOpen {
                    NSWorkspace.shared.open(target)
                }

            case .managedServer(let install, let start, let healthURL, let openURL, let bootTimeoutSeconds, let environment):
                if let install {
                    state = .installing
                    appendLog("Installing dependencies...")
                    let installResult = try await runAndCapture(command: install, cwd: plan.workingDirectory, environment: environment)
                    if installResult.exitCode != 0 {
                        state = .failed("Dependency installation failed")
                        appendLog(installResult.output)
                        return
                    }
                    if !installResult.output.isEmpty {
                        appendLog(installResult.output)
                    }
                }

                state = .starting
                appendLog("Starting server...")
                try launchServer(command: start, cwd: plan.workingDirectory, environment: environment)

                let healthy = await utilities.waitForHealthyURL(healthURL, timeoutSeconds: bootTimeoutSeconds)
                if !healthy {
                    state = .failed("Server did not become healthy in time")
                    appendLog("Health check timeout for \(healthURL.absoluteString)")
                    stop()
                    return
                }

                state = .running
                activeURL = openURL
                appendLog("Server running at \(openURL.absoluteString)")
                if autoOpen {
                    NSWorkspace.shared.open(openURL)
                }
            }
        } catch {
            state = .failed(error.localizedDescription)
            appendLog("Preview failed: \(error.localizedDescription)")
        }
    }

    private func launchServer(command: PreviewCommand, cwd: URL, environment: [String: String]) throws {
        cleanupProcessHandles()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.currentDirectoryURL = cwd
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let outputPipe = Pipe()
        self.outputPipe = outputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8)
            else {
                return
            }

            Task { @MainActor in
                self?.appendLog(text)
            }
        }

        process.terminationHandler = { [weak self] terminated in
            Task { @MainActor in
                self?.cleanupProcessHandles()
                if terminated.terminationStatus != 0 {
                    self?.state = .failed("Server exited unexpectedly (\(terminated.terminationStatus))")
                } else if self?.state == .running {
                    self?.state = .idle
                }
                self?.appendLog("Server exited with status \(terminated.terminationStatus)")
            }
        }

        try process.run()
        self.process = process
    }

    private func runAndCapture(command: PreviewCommand, cwd: URL, environment: [String: String]) async throws -> (exitCode: Int32, output: String) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: command.executable)
                process.arguments = command.arguments
                process.currentDirectoryURL = cwd
                process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: (process.terminationStatus, output))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func cleanupProcessHandles() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        process = nil
    }

    private func appendLog(_ text: String) {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }

        guard !lines.isEmpty else { return }

        logs.append(contentsOf: lines)
        if logs.count > 200 {
            logs.removeFirst(logs.count - 200)
        }
    }
}
