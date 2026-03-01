import AppKit
import Foundation
import SwiftUI
import Combine

@MainActor
final class AgentsDetailViewModel: ObservableObject {
    struct UploadedFile: Identifiable {
        let id: UUID
        let name: String
        let type: String
        let url: URL
        let content: String
    }

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
    @Published var pendingDeleteRun: AgentRun?
    @Published var isAdvancedExpanded = false
    @Published private(set) var uploadedFiles: [UploadedFile] = []

    let advancedCitationModeFieldID = "advancedCitationMode"
    let advancedExtraContextFieldID = "advancedExtraContext"

    private var activeAgentID: String?

    var primaryRunButtonTitle: String {
        if isRunning {
            return "Running..."
        }
        return "Run"
    }

    var uploadedFileItems: [AgentUploadedFileItem] {
        uploadedFiles.map { file in
            AgentUploadedFileItem(id: file.id, name: file.name, type: file.type)
        }
    }

    var hasUploadedFiles: Bool {
        !uploadedFiles.isEmpty
    }

    func selectedValue(for field: AgentInputField) -> String {
        formValues[field.id] ?? ""
    }

    func selectOption(_ option: String, for field: AgentInputField) {
        if option.caseInsensitiveCompare("other") == .orderedSame {
            if formValues[field.id]?.lowercased() != "other" {
                formValues[customValueKey(for: field.id)] = ""
            }
            formValues[field.id] = "other"
            return
        }

        formValues[field.id] = option
        formValues[customValueKey(for: field.id)] = ""
    }

    func isOtherSelected(for field: AgentInputField) -> Bool {
        selectedValue(for: field).lowercased() == "other"
    }

    func customValue(for field: AgentInputField) -> String {
        formValues[customValueKey(for: field.id)] ?? ""
    }

    func setCustomValue(_ value: String, for field: AgentInputField) {
        formValues[customValueKey(for: field.id)] = value
    }

    func activateAgentIfNeeded(_ definition: AgentDefinition, environment: AgentsEnvironment) {
        guard activeAgentID != definition.id else { return }

        activeAgentID = definition.id
        errorMessage = nil
        isRunning = false
        latestRun = nil
        runActivity = nil
        selectedRunID = nil
        pendingDeleteRun = nil
        isAdvancedExpanded = false
        uploadedFiles = []

        var initialValues: [String: String] = [:]
        for field in definition.inputSchema.fields {
            if field.type == .select {
                initialValues[field.id] = field.options.first ?? ""
            } else {
                initialValues[field.id] = ""
            }
        }
        formValues = initialValues
        applyAdvancedDefaultsIfNeeded(definition: definition)

        environment.loadRuns(agentID: definition.id)
        let runs = runsForCurrentAgent(definition.id, environment: environment)
        latestRun = runs.first
        selectedRunID = runs.first?.id
    }

    func runAgent(_ definition: AgentDefinition, environment: AgentsEnvironment) async {
        errorMessage = nil
        let submissionPayload = submissionInputPayload(for: definition)

        let selectedModel = environment.selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            errorMessage = "Please select a model before running."
            return
        }

        for field in definition.inputSchema.fields where field.required {
            let value = (submissionPayload[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if field.type == .url, value.isEmpty, hasUploadedFiles {
                continue
            }
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
                inputPayload: submissionPayload,
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

    func addUploadedFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.prompt = "Add"

        guard panel.runModal() == .OK else {
            return
        }

        var newlyAdded: [UploadedFile] = []
        var failedFiles: [String] = []

        for url in panel.urls {
            if uploadedFiles.contains(where: { $0.url == url }) {
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let content = String(decoding: data, as: UTF8.self)
                let type = fileType(for: url)
                let file = UploadedFile(
                    id: UUID(),
                    name: url.lastPathComponent,
                    type: type,
                    url: url,
                    content: content
                )
                newlyAdded.append(file)
            } catch {
                failedFiles.append(url.lastPathComponent)
            }
        }

        uploadedFiles.append(contentsOf: newlyAdded)

        if !failedFiles.isEmpty {
            errorMessage = "Some files could not be loaded: \(failedFiles.joined(separator: ", "))"
        }
    }

    func removeUploadedFile(id: UUID) {
        uploadedFiles.removeAll { $0.id == id }
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

    private func customValueKey(for fieldID: String) -> String {
        "\(fieldID)__custom"
    }

    private func submissionInputPayload(for definition: AgentDefinition) -> [String: String] {
        var payload: [String: String] = formValues

        for field in definition.inputSchema.fields where field.type == .select {
            let selected = (formValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard selected.lowercased() == "other" else {
                continue
            }

            let custom = (formValues[customValueKey(for: field.id)] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            payload[field.id] = custom
        }

        for field in definition.inputSchema.fields {
            payload.removeValue(forKey: customValueKey(for: field.id))
        }

        payload = payload.filter { key, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        }

        if !uploadedFiles.isEmpty {
            payload["uploadedFiles"] = uploadedFiles.map(\ .name).joined(separator: ", ")

            let combined = uploadedFiles
                .map { file in
                    """
                    ### File: \(file.name)
                    Type: \(file.type)
                    \(file.content)
                    """
                }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !combined.isEmpty {
                payload["uploadedFilesContext"] = combined
            }
        }

        return payload
    }

    private func applyAdvancedDefaultsIfNeeded(definition: AgentDefinition) {
        guard definition.id == "content-summariser" else {
            return
        }

        if formValues[advancedCitationModeFieldID]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            formValues[advancedCitationModeFieldID] = "auto"
        }

        if formValues[advancedExtraContextFieldID] == nil {
            formValues[advancedExtraContextFieldID] = ""
        }
    }

    private func fileType(for url: URL) -> String {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ext.isEmpty ? "file" : ext
    }

}
