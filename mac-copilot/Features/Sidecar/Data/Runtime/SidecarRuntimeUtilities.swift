import Foundation

final class SidecarRuntimeUtilities {
    typealias HealthySidecarReuseDecision = SidecarHealthyReuseDecision

    private let port: Int
    private let commandRunner: SidecarCommandRunning
    private let delaySleeper: BlockingDelaySleeping
    private let healthProbe: SidecarHealthProbe
    private let reusePolicy: SidecarReusePolicy

    init(
        port: Int,
        commandRunner: SidecarCommandRunning = SidecarCommandRunner(),
        healthProbe: SidecarHealthProbe? = nil,
        healthDataFetcher: SidecarHealthDataFetching = URLSessionSidecarHealthDataFetcher(),
        delaySleeper: BlockingDelaySleeping = ThreadBlockingDelaySleeper(),
        reusePolicy: SidecarReusePolicy? = nil
    ) {
        self.port = port
        self.commandRunner = commandRunner
        self.delaySleeper = delaySleeper
        self.healthProbe = healthProbe ?? SidecarHealthProbe(
            port: port,
            healthDataFetcher: healthDataFetcher,
            delaySleeper: delaySleeper
        )
        self.reusePolicy = reusePolicy ?? SidecarReusePolicy()
    }

    func isHealthySidecarAlreadyRunning(requiredSuccesses: Int) -> Bool {
        healthProbe.isHealthySidecarAlreadyRunning(requiredSuccesses: requiredSuccesses)
    }

    func waitForHealthySidecar(timeout: TimeInterval) -> Bool {
        healthProbe.waitForHealthySidecar(timeout: timeout)
    }

    func evaluateHealthySidecarForReuse(
        minimumNodeMajorVersion: Int,
        localRuntimeScriptURL: URL
    ) -> HealthySidecarReuseDecision {
        let healthSnapshot = healthProbe.fetchHealthSnapshot(timeout: 0.9)
        return reusePolicy.evaluate(
            healthSnapshot: healthSnapshot,
            minimumNodeMajorVersion: minimumNodeMajorVersion,
            localRuntimeScriptURL: localRuntimeScriptURL
        )
    }

    func terminateStaleSidecarProcesses(matching scriptPath: String) {
        let pidsOutput = commandRunner.runCommand(executable: "/usr/sbin/lsof", arguments: ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"])
        let pids = pidsOutput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pids.isEmpty else { return }

        for pid in pids {
            let commandLine = commandRunner.runCommand(executable: "/bin/ps", arguments: ["-p", pid, "-o", "command="])
            let normalized = commandLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            guard normalized.contains("node"),
                  (normalized.contains(scriptPath) || normalized.contains("sidecar/index.js"))
            else {
                continue
            }

            _ = commandRunner.runCommand(executable: "/bin/kill", arguments: ["-TERM", pid])
            NSLog("[CopilotForge] Terminated stale sidecar process pid=%@", pid)
        }

        delaySleeper.sleep(seconds: 0.2)
    }
}
