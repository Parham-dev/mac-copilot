import Foundation

extension ControlCenterRuntimeManager {
    func aiDiagnosticsSnapshot(maxEntries: Int = 180) -> String {
        let formatter = ISO8601DateFormatter()
        let stateText: String
        switch state {
        case .idle:
            stateText = "idle"
        case .installing:
            stateText = "installing"
        case .starting:
            stateText = "starting"
        case .running:
            stateText = "running"
        case .failed(let message):
            stateText = "failed: \(message)"
        }

        let projectID = activeProjectID?.uuidString ?? "none"
        let adapter = adapterName ?? "unknown"
        let url = activeURL?.absoluteString ?? "none"

        let entries = logEntries.suffix(maxEntries).map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.phase.rawValue)] [\(entry.stream.rawValue)] \(entry.message)"
        }

        let body = entries.isEmpty ? "(no logs captured yet)" : entries.joined(separator: "\n")

        return """
        Runtime diagnostics
        - projectID: \(projectID)
        - adapter: \(adapter)
        - state: \(stateText)
        - activeURL: \(url)

        Logs:
        \(body)
        """
    }
}
