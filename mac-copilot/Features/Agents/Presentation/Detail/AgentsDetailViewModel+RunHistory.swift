import AppKit
import Foundation
import SwiftUI

extension AgentsDetailViewModel {
    func requestDeleteRun(_ run: AgentRun) {
        pendingDeleteRun = run
    }

    func cancelDeleteRun() {
        pendingDeleteRun = nil
    }

    func confirmDeleteRun(definition: AgentDefinition, environment: AgentsEnvironment) {
        guard let run = pendingDeleteRun else { return }
        pendingDeleteRun = nil
        deleteRun(run, definition: definition, environment: environment)
    }

    func runsForCurrentAgent(_ agentID: String, environment: AgentsEnvironment) -> [AgentRun] {
        environment.runs
            .filter { $0.agentID == agentID }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func selectedRun(from runs: [AgentRun]) -> AgentRun? {
        if let selectedRunID,
           let selected = runs.first(where: { $0.id == selectedRunID }) {
            return selected
        }

        return runs.first
    }

    func ensureSelectedRun(from runs: [AgentRun]) {
        guard !runs.isEmpty else {
            selectedRunID = nil
            return
        }

        if let selectedRunID,
           runs.contains(where: { $0.id == selectedRunID }) {
            return
        }

        selectedRunID = runs.first?.id
    }

    func preferredResultText(for run: AgentRun) -> String? {
        if let finalOutput = run.finalOutput,
           !finalOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return finalOutput
        }

        if let streamedOutput = run.streamedOutput,
           !streamedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return streamedOutput
        }

        return nil
    }

    func displayOutputFormat(for run: AgentRun) -> String {
        let value = run.inputPayload["outputFormat"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch value {
        case "markdown", "markdown brief":
            return "markdown"
        case "json":
            return "json"
        case "text", "bullet":
            return "text"
        default:
            if let finalOutput = run.finalOutput,
               AgentRunResultParser.parse(from: finalOutput) != nil {
                return "json"
            }
            return "text"
        }
    }

    func resultFont(for run: AgentRun) -> Font {
        displayOutputFormat(for: run) == "json"
            ? .system(.callout, design: .monospaced)
            : .callout
    }

    func downloadRunContent(_ run: AgentRun) {
        guard let content = preferredResultText(for: run), !content.isEmpty else {
            errorMessage = "No output available to download."
            return
        }

        let format = displayOutputFormat(for: run)
        let fileExtension = fileExtension(for: format)

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedFileTypes = [fileExtension]
        panel.nameFieldStringValue = suggestedFilename(for: run, fileExtension: fileExtension)

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try content.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Failed to save file. Please try again."
        }
    }

    func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func openRunReport(_ run: AgentRun) {
        let runDirectoryPath = (run.inputPayload["agentRunDirectory"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !runDirectoryPath.isEmpty else {
            errorMessage = "Run report location is unavailable for this run."
            return
        }

        let reportURL = URL(fileURLWithPath: runDirectoryPath, isDirectory: true)
            .appendingPathComponent("run-report.html", isDirectory: false)

        if !FileManager.default.fileExists(atPath: reportURL.path) {
            errorMessage = "Run report not found yet. Re-run the agent to generate it."
            return
        }

        NSWorkspace.shared.open(reportURL)
    }

    private func deleteRun(_ run: AgentRun, definition: AgentDefinition, environment: AgentsEnvironment) {
        errorMessage = nil

        do {
            try environment.deleteRun(id: run.id, agentID: definition.id)

            let refreshedRuns = runsForCurrentAgent(definition.id, environment: environment)
            if latestRun?.id == run.id {
                latestRun = refreshedRuns.first
            }
            ensureSelectedRun(from: refreshedRuns)
        } catch {
            errorMessage = "Failed to delete run. Please try again."
        }
    }

    private func fileExtension(for format: String) -> String {
        switch format {
        case "json":
            return "json"
        case "markdown":
            return "md"
        default:
            return "txt"
        }
    }

    private func suggestedFilename(for run: AgentRun, fileExtension: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: run.startedAt)
        return "agent-\(run.agentID)-\(timestamp).\(fileExtension)"
    }
}
