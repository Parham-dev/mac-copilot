import Foundation

final class SidecarRuntimeUtilities {
    private let port: Int

    init(port: Int) {
        self.port = port
    }

    func isHealthySidecarAlreadyRunning(requiredSuccesses: Int) -> Bool {
        guard let url = URL(string: "http://localhost:\(port)/health") else {
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
}
