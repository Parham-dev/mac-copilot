import Foundation

final class PreviewRuntimeUtilities {
    private let fileManager = FileManager.default

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

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "html" {
                return fileURL
            }
        }

        return nil
    }

    func resolveExecutable(candidates: [String]) -> String? {
        for candidate in candidates {
            let output = runCommand(executable: "/usr/bin/which", arguments: [candidate])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty {
                return candidate
            }
        }
        return nil
    }

    func chooseOpenPort(preferred: [Int]) -> Int {
        for port in preferred where !isPortInUse(port) {
            return port
        }

        for port in 9000 ... 9300 where !isPortInUse(port) {
            return port
        }

        return 8080
    }

    func waitForHealthyURL(_ url: URL, timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 1.2

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse,
                   (200 ... 499).contains(http.statusCode) {
                    return true
                }
            } catch {
                // keep polling
            }

            try? await Task.sleep(nanoseconds: 400_000_000)
        }

        return false
    }

    func readJSON(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any]
        else {
            return nil
        }

        return dict
    }

    private func isPortInUse(_ port: Int) -> Bool {
        let output = runCommand(
            executable: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        )
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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