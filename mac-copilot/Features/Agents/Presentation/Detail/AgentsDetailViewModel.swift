import AppKit
import Foundation
import SwiftUI
import Combine

@MainActor
final class AgentsDetailViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case run = "Run"
        case history = "History"

        var id: String { rawValue }
    }

    @Published var formValues: [String: String] = [:]
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published var latestRun: AgentRun?
    @Published var runActivity: String?
    @Published var selectedTab: Tab = .run
    @Published var selectedRunID: UUID?

    private var activeAgentID: String?

    var canOpenLatestResult: Bool {
        guard let latestRun else { return false }
        return latestRun.status == .completed
    }

    var primaryRunButtonTitle: String {
        if isRunning {
            return "Running..."
        }
        if canOpenLatestResult {
            return "Open Result"
        }
        return "Run"
    }

    func activateAgentIfNeeded(_ definition: AgentDefinition, environment: AgentsEnvironment) {
        guard activeAgentID != definition.id else { return }

        activeAgentID = definition.id
        errorMessage = nil
        isRunning = false
        latestRun = nil
        runActivity = nil
        selectedRunID = nil

        var initialValues: [String: String] = [:]
        for field in definition.inputSchema.fields {
            if field.type == .select {
                initialValues[field.id] = field.options.first ?? ""
            } else {
                initialValues[field.id] = ""
            }
        }
        formValues = initialValues

        environment.loadRuns(agentID: definition.id)
        let runs = runsForCurrentAgent(definition.id, environment: environment)
        latestRun = runs.first
        selectedRunID = runs.first?.id
    }

    func runAgent(_ definition: AgentDefinition, environment: AgentsEnvironment) async {
        errorMessage = nil

        let selectedModel = environment.selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            errorMessage = "Please select a model before running."
            return
        }

        for field in definition.inputSchema.fields where field.required {
            let value = (formValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                errorMessage = "Please fill required field: \(field.label)"
                return
            }
        }

        isRunning = true
        runActivity = "Starting…"
        defer {
            isRunning = false
            runActivity = nil
        }

        do {
            let run = try await environment.executeRun(
                definition: definition,
                projectID: nil,
                inputPayload: formValues,
                model: selectedModel,
                projectPath: nil,
                onProgress: { [weak self] progress in
                    self?.runActivity = progress
                }
            )

            latestRun = run
            selectedRunID = run.id
            selectedTab = .history

            if run.status == .failed {
                errorMessage = "Run completed with a validation or execution issue. See warnings for details."
            }
        } catch {
            errorMessage = "Execution failed. Please retry."
        }
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
