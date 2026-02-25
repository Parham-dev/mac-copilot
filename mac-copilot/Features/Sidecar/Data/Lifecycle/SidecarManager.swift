import Foundation

final class SidecarManager: SidecarLifecycleManaging {
    static let shared = SidecarManager()

    private enum StartReason: String {
        case appBoot = "app_boot"
        case manualRestart = "manual_restart"
        case retry = "retry"
    }

    private let sidecarPort = 7878
    private let queue = DispatchQueue(label: "copilotforge.sidecar.manager", qos: .userInitiated)
    private let startupTimeout: TimeInterval = 8
    private let minimumNodeMajorVersion = 22
    private lazy var preflight = SidecarPreflight(minimumNodeMajorVersion: minimumNodeMajorVersion)
    private let restartPolicy = SidecarRestartPolicy(maxRestartsInWindow: 4, restartWindowSeconds: 60)
    private let logger = SidecarLogger()
    private let stateMachine = SidecarStateMachine()

    private lazy var runtimeUtilities = SidecarRuntimeUtilities(port: sidecarPort)
    private lazy var processController = SidecarProcessController(callbackQueue: queue)

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

            if !self.stateMachine.canRestartWhileNotStarting(isStarting: self.isStarting) {
                self.log("Restart ignored: sidecar is already restarting")
                return
            }

            self.log("Restarting sidecar")
            self.stateMachine.transition(to: .restarting, log: self.log)
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
        if stateMachine.isHealthyRunning(processIsRunning: processController.isRunning) {
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
                let reuseDecision = runtimeUtilities.evaluateHealthySidecarForReuse(
                    minimumNodeMajorVersion: minimumNodeMajorVersion,
                    localRuntimeScriptURL: startup.scriptURL
                )

                if reuseDecision == .reuse {
                    stateMachine.transition(to: .healthy, log: log)
                    log("Existing sidecar detected on :\(sidecarPort), reusing it")
                    return
                }

                let reason: String
                if case .replace(let details) = reuseDecision {
                    reason = details
                } else {
                    reason = "unknown reason"
                }

                log("Existing sidecar detected but must be replaced (\(reason))")
                runtimeUtilities.terminateStaleSidecarProcesses(matching: startup.scriptURL.path)
            }

            if !restartPolicy.canAttemptRestart() {
                let message = "Restart guard tripped: too many restarts in 60s"
                stateMachine.transition(to: .failed(message), log: log)
                log(message)
                return
            }

            runtimeUtilities.terminateStaleSidecarProcesses(matching: startup.scriptURL.path)

            isStarting = true
            stateMachine.transition(to: .starting, log: log)
            runID = UUID().uuidString
            log("Starting sidecar runId=\(runID ?? "n/a") reason=\(reason.rawValue) node=\(startup.nodeExecutable.path) script=\(startup.scriptURL.path)")

            launchProcess(nodeExecutable: startup.nodeExecutable, scriptURL: startup.scriptURL)

            if runtimeUtilities.waitForHealthySidecar(timeout: startupTimeout) {
                restartPolicy.resetRetryAttempt()
                stateMachine.transition(to: .healthy, log: log)
                log("Sidecar healthy on :\(sidecarPort)")
            } else {
                stateMachine.transition(to: .degraded, log: log)
                log("Sidecar failed readiness check within \(Int(startupTimeout))s")
                stopLocked()
                scheduleRetryIfAllowed()
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            stateMachine.transition(to: .failed(message), log: log)
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
            stateMachine.transition(to: .failed("Failed to start sidecar: \(error.localizedDescription)"), log: log)
            log("Failed to start sidecar: \(error.localizedDescription)")
        }
    }

    private func handleTermination(_ termination: SidecarProcessTermination) {
        if stateMachine.handleTermination(termination, log: log) {
            scheduleRetryIfAllowed()
        }
    }

    private func stopLocked() {
        processController.stop()
        stateMachine.transition(to: .stopped, log: log)
    }

    private func scheduleRetryIfAllowed() {
        guard restartPolicy.canAttemptRestart() else {
            let message = "Retry skipped: restart guard tripped"
            stateMachine.transition(to: .failed(message), log: log)
            log(message)
            return
        }

        let delay = restartPolicy.nextRetryDelay()
        log("Scheduling sidecar retry #\(restartPolicy.retryAttempt) in \(String(format: "%.2f", delay))s")

        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startIfNeededLocked(reason: .retry)
        }
    }

    private func log(_ message: String) {
        logger.log(message, runID: runID)
    }
}
