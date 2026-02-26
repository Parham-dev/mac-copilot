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
        let rawLines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }

        guard !rawLines.isEmpty else { return }

        let filteredResult = filterNoisyLines(rawLines)
        var lines = collapseConsecutiveDuplicates(filteredResult.kept)

        if filteredResult.suppressedCount > 0 {
            lines.append("Suppressed \(filteredResult.suppressedCount) noisy local network diagnostics.")
        }

        guard !lines.isEmpty else { return }

        logs.append(contentsOf: lines)
        if logs.count > maxUILogLines {
            logs.removeFirst(logs.count - maxUILogLines)
        }

        for line in lines {
            logEntries.append(
                RuntimeLogEntry(
                    timestamp: clock.now,
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

    private func filterNoisyLines(_ lines: [String]) -> (kept: [String], suppressedCount: Int) {
        var kept: [String] = []
        var suppressedCount = 0

        for line in lines {
            if shouldSuppressNoiseLine(line) {
                suppressedCount += 1
                continue
            }

            kept.append(line)
        }

        return (kept, suppressedCount)
    }

    private func shouldSuppressNoiseLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let noisyPrefixes = [
            "nw_socket_handle_socket_event",
            "nw_endpoint_flow_failed_with_error",
            "nw_connection_copy_protocol_metadata_internal_block_invoke",
            "nw_connection_copy_connected_local_endpoint_block_invoke",
            "nw_connection_copy_connected_remote_endpoint_block_invoke",
            "Connection ",
            "Task <",
            "_NSURLError",
            "NSErrorFailingURL",
            "NSLocalizedDescription=Could not connect to the server",
            "_kCFStreamError",
            "), NSLocalizedDescription=Could not connect to the server"
        ]

        if noisyPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            return true
        }

        if trimmed.contains("Code=-1004") || trimmed.contains("error(1:61)") {
            return true
        }

        return false
    }

    private func collapseConsecutiveDuplicates(_ lines: [String]) -> [String] {
        guard !lines.isEmpty else { return [] }

        var collapsed: [String] = []
        var previous = logs.last

        for line in lines {
            if previous == line {
                continue
            }

            collapsed.append(line)
            previous = line
        }

        return collapsed
    }
}
