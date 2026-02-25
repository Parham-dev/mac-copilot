import Foundation

final class SidecarRuntimeUtilities {
    enum HealthySidecarReuseDecision: Equatable {
        case reuse
        case replace(String)
    }

    private struct HealthPayload: Decodable {
        let ok: Bool?
        let service: String?
        let nodeVersion: String?
        let nodeExecPath: String?
        let processStartedAtMs: Double?
    }

    private let port: Int

    init(port: Int) {
        self.port = port
    }

    func isHealthySidecarAlreadyRunning(requiredSuccesses: Int) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            return false
        }

        let attempts = max(requiredSuccesses, 1)
        var successes = 0

        for _ in 0 ..< attempts {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 0.8

            let semaphore = DispatchSemaphore(value: 0)
            var isHealthy = false

            let task = URLSession.shared.dataTask(with: request) { data, response, _ in
                defer { semaphore.signal() }

                guard let http = response as? HTTPURLResponse,
                      (200 ... 299).contains(http.statusCode),
                      let data,
                      let body = String(data: data, encoding: .utf8),
                      body.contains("copilotforge-sidecar")
                else {
                    return
                }

                isHealthy = true
            }

            task.resume()
            _ = semaphore.wait(timeout: .now() + 1.0)

            if isHealthy {
                successes += 1
                Thread.sleep(forTimeInterval: 0.12)
            } else {
                return false
            }
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

    func evaluateHealthySidecarForReuse(
        minimumNodeMajorVersion: Int,
        localRuntimeScriptURL: URL
    ) -> HealthySidecarReuseDecision {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            return .replace("health endpoint URL is invalid")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.9

        let semaphore = DispatchSemaphore(value: 0)
        var decision: HealthySidecarReuseDecision = .replace("healthy sidecar metadata is unavailable")

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }

            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode),
                  let data,
                  let payload = try? JSONDecoder().decode(HealthPayload.self, from: data),
                  payload.service == "copilotforge-sidecar"
            else {
                decision = .replace("healthy sidecar did not return a valid health payload")
                return
            }

            guard let version = payload.nodeVersion,
                  let major = Self.parseNodeMajor(version)
            else {
                decision = .replace("running sidecar node version is missing")
                return
            }

            guard major >= minimumNodeMajorVersion else {
                NSLog("[CopilotForge] Running sidecar node runtime is incompatible (version=%@, exec=%@)", version, payload.nodeExecPath ?? "unknown")
                decision = .replace("running sidecar node runtime is incompatible")
                return
            }

            guard let processStartedAtMs = payload.processStartedAtMs, processStartedAtMs > 0 else {
                decision = .replace("running sidecar is missing process start metadata")
                return
            }

            let localRuntimeUpdatedAtMs = latestRuntimeUpdatedAtMs(referenceScriptURL: localRuntimeScriptURL)
            if processStartedAtMs + 500 < localRuntimeUpdatedAtMs {
                decision = .replace("running sidecar started before the latest runtime build")
                return
            }

            decision = .reuse
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + 1.2)
        return decision
    }

    func terminateStaleSidecarProcesses(matching scriptPath: String) {
        let pidsOutput = runCommand(executable: "/usr/sbin/lsof", arguments: ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"])
        let pids = pidsOutput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pids.isEmpty else { return }

        for pid in pids {
            let commandLine = runCommand(executable: "/bin/ps", arguments: ["-p", pid, "-o", "command="])
            let normalized = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)

            guard normalized.contains("node"),
                  (normalized.contains(scriptPath) || normalized.contains("sidecar/index.js"))
            else {
                continue
            }

            _ = runCommand(executable: "/bin/kill", arguments: ["-TERM", pid])
            NSLog("[CopilotForge] Terminated stale sidecar process pid=%@", pid)
        }

        Thread.sleep(forTimeInterval: 0.2)
    }

    private func runCommand(executable: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseNodeMajor(_ versionString: String) -> Int? {
        let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let numeric = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        guard let token = numeric.split(separator: ".").first,
              let major = Int(token)
        else {
            return nil
        }
        return major
    }

    private func latestRuntimeUpdatedAtMs(referenceScriptURL: URL) -> Double {
        let fileManager = FileManager.default
        let scriptPath = referenceScriptURL.path
        var newestDate = modificationDate(forPath: scriptPath, fileManager: fileManager) ?? .distantPast

        let distDirectoryURL = referenceScriptURL.deletingLastPathComponent()
        if let enumerator = fileManager.enumerator(at: distDirectoryURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for case let fileURL as URL in enumerator {
                let candidateDate = modificationDate(forPath: fileURL.path, fileManager: fileManager)
                if let candidateDate, candidateDate > newestDate {
                    newestDate = candidateDate
                }
            }
        }

        return newestDate.timeIntervalSince1970 * 1000
    }

    private func modificationDate(forPath path: String, fileManager: FileManager) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return nil
        }

        return attributes[.modificationDate] as? Date
    }
}
