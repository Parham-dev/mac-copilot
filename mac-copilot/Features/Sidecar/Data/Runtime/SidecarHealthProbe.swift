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

    init(port: Int) {
        self.port = port
    }

    func isHealthySidecarAlreadyRunning(requiredSuccesses: Int) -> Bool {
        let attempts = max(requiredSuccesses, 1)
        var successes = 0

        for _ in 0 ..< attempts {
            guard isHealthyOnce(timeout: 0.8) else {
                return false
            }

            successes += 1
            Thread.sleep(forTimeInterval: 0.12)
        }

        return successes == attempts
    }

    func waitForHealthySidecar(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isHealthySidecarAlreadyRunning(requiredSuccesses: 2) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
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
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }

            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode),
                  let data
            else {
                return
            }

            result = data
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 0.4)
        return result
    }
}
