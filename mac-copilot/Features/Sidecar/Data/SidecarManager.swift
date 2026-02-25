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
    private let logger = SidecarLogger()

    private lazy var runtimeUtilities = SidecarRuntimeUtilities(port: sidecarPort)
    private lazy var processController = SidecarProcessController(callbackQueue: queue)

    private var state: SidecarState = .stopped
    private var isStarting = false
    private var runID: String?

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
        if processController.isRunning, state == .healthy {
            return
        }

        if isStarting {
            log("Start ignored: already starting")
            return
        }

        if processController.hasStaleProcessHandle() {
            log("Clearing stale process handle")
            processController.clearStaleProcessHandle()
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
        do {
            try processController.start(
                nodeExecutable: nodeExecutable,
                scriptURL: scriptURL,
                outputHandler: { text in
                    NSLog("[CopilotForge][Sidecar] %@", text)
                },
                terminationHandler: { [weak self] termination in
                    self?.handleTermination(termination)
                }
            )
            log("Sidecar process launched")
        } catch {
            transition(to: .failed("Failed to start sidecar: \(error.localizedDescription)"))
            log("Failed to start sidecar: \(error.localizedDescription)")
        }
    }

    private func handleTermination(_ termination: SidecarProcessTermination) {
        log("Sidecar terminated (reason=\(termination.reasonRawValue), status=\(termination.status))")

        if termination.intentional {
            log("Intentional sidecar termination acknowledged")
            if case .restarting = state {
                transition(to: .stopped)
            }
            return
        }

        if state == .healthy || state == .starting {
            transition(to: .degraded)
            scheduleRetryIfAllowed()
        } else if case .restarting = state {
            transition(to: .stopped)
        }
    }

    private func stopLocked() {
        processController.stop()
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
        logger.log(message, runID: runID)
    }
}
