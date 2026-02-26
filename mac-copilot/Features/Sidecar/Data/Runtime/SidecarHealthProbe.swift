import Foundation

struct SidecarHealthSnapshot {
    let service: String?
    let nodeVersion: String?
    let nodeExecPath: String?
    let processStartedAtMs: Double?
}

private struct SidecarHealthPayload: Decodable {
    let ok: Bool?
    let service: String?
    let nodeVersion: String?
    let nodeExecPath: String?
    let processStartedAtMs: Double?
}

final class SidecarHealthProbe {
    private let port: Int
    private let healthDataFetcher: SidecarHealthDataFetching
    private let delaySleeper: BlockingDelaySleeping
    private let clock: ClockProviding

    init(
        port: Int,
        healthDataFetcher: SidecarHealthDataFetching = URLSessionSidecarHealthDataFetcher(),
        delaySleeper: BlockingDelaySleeping = ThreadBlockingDelaySleeper(),
        clock: ClockProviding = SystemClockProvider()
    ) {
        self.port = port
        self.healthDataFetcher = healthDataFetcher
        self.delaySleeper = delaySleeper
        self.clock = clock
    }

    func isHealthySidecarAlreadyRunning(requiredSuccesses: Int) -> Bool {
        let attempts = max(requiredSuccesses, 1)
        var successes = 0

        for _ in 0 ..< attempts {
            guard isHealthyOnce(timeout: 0.8) else {
                return false
            }

            successes += 1
            delaySleeper.sleep(seconds: 0.12)
        }

        return successes == attempts
    }

    func waitForHealthySidecar(timeout: TimeInterval) -> Bool {
        let deadline = clock.now.addingTimeInterval(timeout)
        while clock.now < deadline {
            if isHealthySidecarAlreadyRunning(requiredSuccesses: 2) {
                return true
            }
            delaySleeper.sleep(seconds: 0.25)
        }
        return false
    }

    func fetchHealthSnapshot(timeout: TimeInterval) -> SidecarHealthSnapshot? {
        guard let data = healthData(timeout: timeout) else {
            return nil
        }

        guard let payload = try? JSONDecoder().decode(SidecarHealthPayload.self, from: data),
              payload.service == "copilotforge-sidecar"
        else {
            return nil
        }

        return SidecarHealthSnapshot(
            service: payload.service,
            nodeVersion: payload.nodeVersion,
            nodeExecPath: payload.nodeExecPath,
            processStartedAtMs: payload.processStartedAtMs
        )
    }

    private func isHealthyOnce(timeout: TimeInterval) -> Bool {
        guard let data = healthData(timeout: timeout),
              let body = String(data: data, encoding: .utf8)
        else {
            return false
        }

        return body.contains("copilotforge-sidecar")
    }

    private func healthData(timeout: TimeInterval) -> Data? {
        healthDataFetcher.fetchHealthData(port: port, timeout: timeout)
    }
}
