import Foundation

extension ControlCenterRuntimeManager {
    func failWithError(_ message: String) {
        if case .failed = state {
            appendLog(message, phase: .lifecycle, stream: .stderr)
            return
        }

        state = .failed(message.replacingOccurrences(of: "Control center failed: ", with: ""))
        appendLog(message, phase: .lifecycle, stream: .stderr)
    }

    func appendLog(_ text: String, phase: LogPhase = .runtime, stream: LogStream = .system) {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }

        guard !lines.isEmpty else { return }

        logs.append(contentsOf: lines)
        if logs.count > maxUILogLines {
            logs.removeFirst(logs.count - maxUILogLines)
        }

        for line in lines {
            logEntries.append(
                RuntimeLogEntry(
                    timestamp: Date(),
                    phase: phase,
                    stream: stream,
                    message: line
                )
            )
        }

        if logEntries.count > maxDiagnosticLogEntries {
            logEntries.removeFirst(logEntries.count - maxDiagnosticLogEntries)
        }
    }
}
