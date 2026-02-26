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

            Task { @MainActor [weak self] in
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

            Task { @MainActor [weak self] in
                self?.appendLog(text, phase: .runtime, stream: .stderr)
            }
        }

        process.terminationHandler = { [weak self] terminated in
            Task { @MainActor [weak self] in
                let wasStopRequested = self?.isStopRequested ?? false
                let resetUIAfterStop = self?.shouldResetUIAfterStop ?? false
                let clearLogsAfterStop = self?.shouldClearLogsAfterStop ?? false

                if self?.process?.processIdentifier != terminated.processIdentifier {
                    return
                }

                self?.cleanupProcessHandles()
                if wasStopRequested {
                    self?.isStopRequested = false
                    self?.shouldResetUIAfterStop = false
                    self?.shouldClearLogsAfterStop = false

                    if resetUIAfterStop {
                        self?.activeURL = nil
                        self?.adapterName = nil
                        self?.activeProjectID = nil
                    }

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

        let readyURL = await waitForHealthyURLOrEarlyFailure(healthURL, timeoutSeconds: bootTimeoutSeconds)
        if let readyURL {
            state = .running
            activeURL = readyURL

            if readyURL == openURL {
                appendLog("Server running at \(readyURL.absoluteString)", phase: .health)
            } else {
                appendLog("Server running at \(readyURL.absoluteString) (detected from runtime output)", phase: .health)
            }

            if autoOpen {
                NSWorkspace.shared.open(readyURL)
            }

            return .healthy
        }

        if !isProcessActive {
            let failedPort = healthURL.port
            state = .failed("Server did not become healthy in time")
            appendLog("Health check timeout for \(healthURL.absoluteString)", phase: .health, stream: .stderr)
            return .unhealthy(failedPort: failedPort)
        }

        if let runtimeURL = detectRuntimeURLFromRecentRuntimeLogs() {
            if isProcessActive,
               runtimeURL.absoluteString.hasPrefix("http") {
                state = .running
                activeURL = runtimeURL
                appendLog("Server running at \(runtimeURL.absoluteString) (detected from runtime output)", phase: .health)
                if autoOpen {
                    NSWorkspace.shared.open(runtimeURL)
                }
                return .healthy
            }
        }

        let failedPort = healthURL.port
        state = .failed("Server did not become healthy in time")
        appendLog("Health check timeout for \(healthURL.absoluteString)", phase: .health, stream: .stderr)
        return .unhealthy(failedPort: failedPort)
    }

    func waitForHealthyURLOrEarlyFailure(_ url: URL, timeoutSeconds: TimeInterval) async -> URL? {
        let deadline = clock.now.addingTimeInterval(timeoutSeconds)

        guard let port = url.port else {
            appendLog("Health URL has no explicit port: \(url.absoluteString)", phase: .health, stream: .stderr)
            return nil
        }

        var hasLoggedPortListening = false

        while clock.now < deadline {
            if !isProcessActive {
                appendLog("Server process ended before health check succeeded", phase: .health, stream: .stderr)
                return nil
            }

            if let runtimeURL = detectRuntimeURLFromRecentRuntimeLogs() {
                return runtimeURL
            }

            if utilities.isLocalPortListening(port) {
                if !hasLoggedPortListening {
                    appendLog("Port \(port) is listening. Verifying HTTP readiness...", phase: .health)
                    hasLoggedPortListening = true
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 1.2

                do {
                    let (_, response) = try await healthTransport.data(for: request)
                    if let http = response as? HTTPURLResponse,
                       (200 ... 499).contains(http.statusCode) {
                        return url
                    }
                } catch {
                    // keep polling
                }
            }

            try? await delayScheduler.sleep(seconds: 0.35)
        }

        appendLog("Server never opened expected port \(port) before timeout", phase: .health, stream: .stderr)
        return nil
    }

    var isProcessActive: Bool {
        guard let process else {
            return false
        }

        return process.isRunning
    }

    func runAndCapture(command: ControlCenterCommand, cwd: URL, environment: [String: String]) async throws -> (exitCode: Int32, output: String) {
        let result = try await commandRunner.runCommand(
            executable: command.executable,
            arguments: command.arguments,
            cwd: cwd,
            environment: environment
        )
        return (result.exitCode, result.output)
    }

    func cleanupProcessHandles() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
    }

    private func detectRuntimeURLFromRecentRuntimeLogs() -> URL? {
        let pattern = "https?://(?:localhost|127\\.0\\.0\\.1):[0-9]{2,5}(?:/[^\\s]*)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        for entry in logEntries.suffix(220).reversed() {
            guard entry.phase == .runtime else {
                continue
            }

            let line = entry.message
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, options: [], range: nsRange),
                  let urlRange = Range(match.range, in: line)
            else {
                continue
            }

            let candidate = String(line[urlRange])
            if let url = URL(string: candidate) {
                return url
            }
        }

        return nil
    }
}
