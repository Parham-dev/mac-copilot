import Foundation

protocol SidecarPreflightChecking {
    func check() throws -> SidecarStartupConfig
}

protocol SidecarRuntimeUtilityManaging {
    func isHealthySidecarAlreadyRunning(requiredSuccesses: Int) -> Bool
    func waitForHealthySidecar(timeout: TimeInterval) -> Bool
    func evaluateHealthySidecarForReuse(
        minimumNodeMajorVersion: Int,
        localRuntimeScriptURL: URL
    ) -> SidecarHealthyReuseDecision
    func terminateStaleSidecarProcesses(matching scriptPath: String)
}

protocol SidecarProcessControlling {
    var isRunning: Bool { get }
    func hasStaleProcessHandle() -> Bool
    func clearStaleProcessHandle()
    func start(
        nodeExecutable: URL,
        scriptURL: URL,
        outputHandler: @escaping (String) -> Void,
        terminationHandler: @escaping (SidecarProcessTermination) -> Void
    ) throws
    func stop()
}

protocol SidecarRestartPolicyManaging {
    var retryAttempt: Int { get }
    func canAttemptRestart(now: Date) -> Bool
    func resetRetryAttempt()
    func nextRetryDelay() -> TimeInterval
}

protocol SidecarLogWriting {
    func log(_ message: String, runID: String?)
}

extension SidecarPreflight: SidecarPreflightChecking {}
extension SidecarRuntimeUtilities: SidecarRuntimeUtilityManaging {}
extension SidecarProcessController: SidecarProcessControlling {}
extension SidecarRestartPolicy: SidecarRestartPolicyManaging {}
extension SidecarLogger: SidecarLogWriting {}
