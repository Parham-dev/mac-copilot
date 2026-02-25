import Foundation

final class SidecarManager: SidecarLifecycleManaging {
    static let shared = SidecarManager()

    private enum SidecarState: Equatable {
        case stopped
        case starting
        case healthy
        case degraded
        case restarting
        case failed(String)
    }

    private enum StartReason: String {
        case appBoot = "app_boot"
        case manualRestart = "manual_restart"
        case retry = "retry"
    }

    private let sidecarPort = 7878
    private let queue = DispatchQueue(label: "copilotforge.sidecar.manager", qos: .userInitiated)
    private let startupTimeout: TimeInterval = 8
    private let preflight = SidecarPreflight(minimumNodeMajorVersion: 20)
    private let restartPolicy = SidecarRestartPolicy(maxRestartsInWindow: 4, restartWindowSeconds: 60)

    private lazy var runtimeUtilities = SidecarRuntimeUtilities(port: sidecarPort)

    private var process: Process?
    private var outputPipe: Pipe?
    private var state: SidecarState = .stopped
    private var isStarting = false
    private var runID: String?
    private var intentionallyTerminatedPIDs: Set<Int32> = []

    private init() {}

    func startIfNeeded() {
        queue.async { [weak self] in
            self?.startIfNeededLocked(reason: .appBoot)
        }
    }

    func restart() {
        queue.async { [weak self] in
            guard let self else { return }

            if self.state == .restarting || self.isStarting {
                self.log("Restart ignored: sidecar is already restarting")
                return
            }

            self.log("Restarting sidecar")
            self.transition(to: .restarting)
            self.stopLocked()
            self.startIfNeededLocked(reason: .manualRestart)
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    private func startIfNeededLocked(reason: StartReason) {
        if let process, process.isRunning, state == .healthy {
            return
        }

        if isStarting {
            log("Start ignored: already starting")
            return
        }

        if let process, !process.isRunning {
            log("Clearing stale process handle")
            self.process = nil
        }

        do {
            let startup = try preflight.check()
            log("Preflight OK nodeVersion=\(startup.nodeVersion)")

            if runtimeUtilities.isHealthySidecarAlreadyRunning(requiredSuccesses: 2) {
                transition(to: .healthy)
                log("Existing sidecar detected on :\(sidecarPort), reusing it")
                return
            }

            if !restartPolicy.canAttemptRestart() {
                let message = "Restart guard tripped: too many restarts in 60s"
                transition(to: .failed(message))
                log(message)
                return
            }

            runtimeUtilities.terminateStaleSidecarProcesses(matching: startup.scriptURL.path)

            isStarting = true
            transition(to: .starting)
            runID = UUID().uuidString
            log("Starting sidecar runId=\(runID ?? "n/a") reason=\(reason.rawValue) node=\(startup.nodeExecutable.path) script=\(startup.scriptURL.path)")

            launchProcess(nodeExecutable: startup.nodeExecutable, scriptURL: startup.scriptURL)

            if runtimeUtilities.waitForHealthySidecar(timeout: startupTimeout) {
                restartPolicy.resetRetryAttempt()
                transition(to: .healthy)
                log("Sidecar healthy on :\(sidecarPort)")
            } else {
                transition(to: .degraded)
                log("Sidecar failed readiness check within \(Int(startupTimeout))s")
                stopLocked()
                scheduleRetryIfAllowed()
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            transition(to: .failed(message))
            log(message)
        }

        isStarting = false
    }

    private func launchProcess(nodeExecutable: URL, scriptURL: URL) {
        let process = Process()
        process.executableURL = nodeExecutable
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["NODE_NO_WARNINGS"] = "1"
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
            if !trimmed.isEmpty {
                NSLog("[CopilotForge][Sidecar] %@", trimmed)
            }
        }

        process.terminationHandler = { [weak self] process in
            guard let self else { return }

            self.queue.async {
                self.log("Sidecar terminated (reason=\(process.terminationReason.rawValue), status=\(process.terminationStatus))")

                if self.intentionallyTerminatedPIDs.remove(process.processIdentifier) != nil {
                    self.log("Intentional sidecar termination acknowledged")
                    self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                    self.outputPipe = nil
                    if self.process?.processIdentifier == process.processIdentifier {
                        self.process = nil
                    }
                    if case .restarting = self.state {
                        self.transition(to: .stopped)
                    }
                    return
                }

                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.outputPipe = nil
                self.process = nil

                if self.state == .healthy || self.state == .starting {
                    self.transition(to: .degraded)
                    self.scheduleRetryIfAllowed()
                } else if case .restarting = self.state {
                    self.transition(to: .stopped)
                }
            }
        }

        do {
            try process.run()
            self.process = process
            log("Sidecar process launched")
        } catch {
            transition(to: .failed("Failed to start sidecar: \(error.localizedDescription)"))
            log("Failed to start sidecar: \(error.localizedDescription)")
        }
    }

    private func stopLocked() {
        if let pid = process?.processIdentifier {
            intentionallyTerminatedPIDs.insert(pid)
        }
        process?.terminate()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        process = nil
        transition(to: .stopped)
    }

    private func scheduleRetryIfAllowed() {
        guard restartPolicy.canAttemptRestart() else {
            let message = "Retry skipped: restart guard tripped"
            transition(to: .failed(message))
            log(message)
            return
        }

        let delay = restartPolicy.nextRetryDelay()
        log("Scheduling sidecar retry #\(restartPolicy.retryAttempt) in \(String(format: "%.2f", delay))s")

        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startIfNeededLocked(reason: .retry)
        }
    }

    private func transition(to next: SidecarState) {
        guard next != state else { return }
        state = next
        log("State => \(describe(state: next))")
    }

    private func describe(state: SidecarState) -> String {
        switch state {
        case .stopped:
            return "stopped"
        case .starting:
            return "starting"
        case .healthy:
            return "healthy"
        case .degraded:
            return "degraded"
        case .restarting:
            return "restarting"
        case .failed(let message):
            return "failed(\(message))"
        }
    }

    private func log(_ message: String) {
        if let runID {
            NSLog("[CopilotForge][Sidecar][run:%@] %@", runID, message)
        } else {
            NSLog("[CopilotForge][Sidecar] %@", message)
        }
    }
}
