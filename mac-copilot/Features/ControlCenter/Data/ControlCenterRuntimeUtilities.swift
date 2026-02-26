import Foundation

final class ControlCenterRuntimeUtilities {
    private let fileManager: ControlCenterFileManaging
    private let commandRunner: ControlCenterCommandRunning
    private let transport: HTTPDataTransporting
    private let delayScheduler: AsyncDelayScheduling
    private let blockingSleeper: BlockingDelaySleeping
    private let dateProvider: DateProviding
    private static var reservedPorts: [Int: Date] = [:]

    init(
        fileManager: ControlCenterFileManaging = FileManagerControlCenterFileManager(),
        commandRunner: ControlCenterCommandRunning = ProcessControlCenterCommandRunner(),
        transport: HTTPDataTransporting = URLSessionHTTPDataTransport(),
        delayScheduler: AsyncDelayScheduling = TaskAsyncDelayScheduler(),
        blockingSleeper: BlockingDelaySleeping = ThreadBlockingDelaySleeper(),
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.fileManager = fileManager
        self.commandRunner = commandRunner
        self.transport = transport
        self.delayScheduler = delayScheduler
        self.blockingSleeper = blockingSleeper
        self.dateProvider = dateProvider
    }

    func expandedProjectURL(for project: ProjectRef) -> URL {
        let expanded = (project.localPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    func fileExists(_ name: String, in directory: URL) -> Bool {
        let path = directory.appendingPathComponent(name).path
        return fileManager.fileExists(atPath: path)
    }

    func firstHTMLFile(in directory: URL) -> URL? {
        let indexURL = directory.appendingPathComponent("index.html")
        if fileManager.fileExists(atPath: indexURL.path) {
            return indexURL
        }

        return fileManager.htmlFilesRecursively(in: directory).first
    }

    func resolveExecutable(candidates: [String]) -> String? {
        for candidate in candidates {
            if candidate.contains("/") {
                let expanded = (candidate as NSString).expandingTildeInPath
                if fileManager.isExecutableFile(atPath: expanded) {
                    return expanded
                }
            }

            let output = commandRunner.runCommand(executable: "/usr/bin/which", arguments: [candidate])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty {
                return output
            }

            for prefix in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] {
                let path = "\(prefix)/\(candidate)"
                if fileManager.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }

    func chooseOpenPort(preferred: [Int]) -> Int {
        purgeExpiredReservedPorts()

        for port in preferred where !isPortInUse(port) {
            if Self.reservedPorts[port] != nil {
                continue
            }
            return port
        }

        for port in 9000 ... 9300 where !isPortInUse(port) {
            if Self.reservedPorts[port] != nil {
                continue
            }
            return port
        }

        return 8080
    }

    func reservePortTemporarily(_ port: Int, ttlSeconds: TimeInterval) {
        Self.reservedPorts[port] = dateProvider.now.addingTimeInterval(ttlSeconds)
    }

    func isLocalPortListening(_ port: Int) -> Bool {
        isPortInUse(port)
    }

    func freeLocalPortIfNeeded(_ port: Int) -> (freed: Bool, details: String) {
        let pids = processIDsListening(on: port)
        guard !pids.isEmpty else {
            return (true, "No running process was holding port \(port).")
        }

        for pid in pids {
            _ = commandRunner.runCommand(executable: "/bin/kill", arguments: ["-TERM", String(pid)])
        }

        if waitForPortToClose(port, timeoutSeconds: 1.8) {
            return (true, "Stopped process(es) \(pids.map(String.init).joined(separator: ", ")) on port \(port).")
        }

        let remaining = processIDsListening(on: port)
        for pid in remaining {
            _ = commandRunner.runCommand(executable: "/bin/kill", arguments: ["-KILL", String(pid)])
        }

        if waitForPortToClose(port, timeoutSeconds: 1.2) {
            return (true, "Force-stopped process(es) \(remaining.map(String.init).joined(separator: ", ")) on port \(port).")
        }

        return (false, "Could not free port \(port). Processes still listening: \(processIDsListening(on: port).map(String.init).joined(separator: ", ")).")
    }

    func waitForHealthyURL(_ url: URL, timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = dateProvider.now.addingTimeInterval(timeoutSeconds)

        while dateProvider.now < deadline {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 1.2

            do {
                let (_, response) = try await transport.data(for: request)
                if let http = response as? HTTPURLResponse,
                   (200 ... 499).contains(http.statusCode) {
                    return true
                }
            } catch {
                // keep polling
            }

            try? await delayScheduler.sleep(seconds: 0.4)
        }

        return false
    }

    func readJSON(at url: URL) -> [String: Any]? {
        guard let data = fileManager.readData(at: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any]
        else {
            return nil
        }

        return dict
    }

    private func isPortInUse(_ port: Int) -> Bool {
        let output = commandRunner.runCommand(
            executable: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        )
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func processIDsListening(on port: Int) -> [Int] {
        let output = commandRunner.runCommand(
            executable: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        )

        let parsed = output
            .split(separator: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        var unique: [Int] = []
        var seen: Set<Int> = []
        for pid in parsed where !seen.contains(pid) {
            seen.insert(pid)
            unique.append(pid)
        }

        return unique
    }

    private func waitForPortToClose(_ port: Int, timeoutSeconds: TimeInterval) -> Bool {
        let deadline = dateProvider.now.addingTimeInterval(timeoutSeconds)

        while dateProvider.now < deadline {
            if !isPortInUse(port) {
                return true
            }

            blockingSleeper.sleep(seconds: 0.2)
        }

        return !isPortInUse(port)
    }

    private func purgeExpiredReservedPorts() {
        let now = dateProvider.now
        Self.reservedPorts = Self.reservedPorts.filter { $0.value > now }
    }
}