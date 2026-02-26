import Foundation
import AppKit

extension ControlCenterRuntimeManager {
    func launchServer(command: ControlCenterCommand, cwd: URL, environment: [String: String]) throws {
        cleanupProcessHandles()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.currentDirectoryURL = cwd
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8)
            else {
                return
            }

            Task { @MainActor in
                self?.appendLog(text, phase: .runtime, stream: .stdout)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8)
            else {
                return
            }

            Task { @MainActor in
                self?.appendLog(text, phase: .runtime, stream: .stderr)
            }
        }

        process.terminationHandler = { [weak self] terminated in
            Task { @MainActor in
                let wasStopRequested = self?.isStopRequested ?? false
                let clearLogsAfterStop = self?.shouldClearLogsAfterStop ?? false

                self?.cleanupProcessHandles()
                if wasStopRequested {
                    self?.isStopRequested = false
                    self?.shouldClearLogsAfterStop = false

                    if clearLogsAfterStop {
                        self?.logs.removeAll(keepingCapacity: true)
                        self?.logEntries.removeAll(keepingCapacity: true)
                    } else {
                        self?.appendLog("Stopped control center runtime", phase: .lifecycle)
                    }

                    self?.state = .idle
                    return
                }

                if terminated.terminationStatus != 0 {
                    self?.state = .failed("Server exited unexpectedly (\(terminated.terminationStatus))")
                } else if self?.state == .running {
                    self?.state = .idle
                }
                self?.appendLog("Server exited with status \(terminated.terminationStatus)", phase: .lifecycle)
            }
        }

        try process.run()
        self.process = process
    }

    func launchAndAwaitHealth(
        start: ControlCenterCommand,
        cwd: URL,
        environment: [String: String],
        healthURL: URL,
        bootTimeoutSeconds: TimeInterval,
        openURL: URL,
        autoOpen: Bool
    ) async throws -> LaunchHealthResult {
        try launchServer(command: start, cwd: cwd, environment: environment)

        let healthy = await waitForHealthyURLOrEarlyFailure(healthURL, timeoutSeconds: bootTimeoutSeconds)
        if !healthy {
            let failedPort = healthURL.port
            state = .failed("Server did not become healthy in time")
            appendLog("Health check timeout for \(healthURL.absoluteString)", phase: .health, stream: .stderr)
            return .unhealthy(failedPort: failedPort)
        }

        state = .running
        activeURL = openURL
        appendLog("Server running at \(openURL.absoluteString)", phase: .health)
        if autoOpen {
            NSWorkspace.shared.open(openURL)
        }
        return .healthy
    }

    func waitForHealthyURLOrEarlyFailure(_ url: URL, timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        guard let port = url.port else {
            appendLog("Health URL has no explicit port: \(url.absoluteString)", phase: .health, stream: .stderr)
            return false
        }

        let listening = await waitForListeningPortOrEarlyFailure(port: port, deadline: deadline)
        if !listening {
            return false
        }

        let probeSession = URLSession(configuration: .ephemeral)

        while Date() < deadline {
            if !isProcessActive {
                appendLog("Server process ended before health check succeeded", phase: .health, stream: .stderr)
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 1.2

            do {
                let (_, response) = try await probeSession.data(for: request)
                if let http = response as? HTTPURLResponse,
                   (200 ... 499).contains(http.statusCode) {
                    return true
                }
            } catch {
                // keep polling
            }

            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        return false
    }

    func waitForListeningPortOrEarlyFailure(port: Int, deadline: Date) async -> Bool {
        while Date() < deadline {
            if !isProcessActive {
                appendLog("Server process ended before opening port \(port)", phase: .health, stream: .stderr)
                return false
            }

            if utilities.isLocalPortListening(port) {
                appendLog("Port \(port) is listening. Verifying HTTP readiness...", phase: .health)
                return true
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        appendLog("Server never opened port \(port) before timeout", phase: .health, stream: .stderr)
        return false
    }

    var isProcessActive: Bool {
        guard let process else {
            return false
        }

        return process.isRunning
    }

    func runAndCapture(command: ControlCenterCommand, cwd: URL, environment: [String: String]) async throws -> (exitCode: Int32, output: String) {
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

    func cleanupProcessHandles() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
    }
}
