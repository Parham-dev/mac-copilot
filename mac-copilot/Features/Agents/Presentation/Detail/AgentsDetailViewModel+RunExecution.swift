import Foundation

extension AgentsDetailViewModel {
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
        let resolvedProjectPath = (submissionPayload["projectPath"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let selectedModel = environment.selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            errorMessage = "Please select a model before running."
            return
        }

        if let validationError = validationError(definition: definition, submissionPayload: submissionPayload) {
            errorMessage = validationError
            return
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
                projectPath: resolvedProjectPath.isEmpty ? nil : resolvedProjectPath,
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

    func customValueKey(for fieldID: String) -> String {
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

        payload = payload.filter { _, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        }

        appendUploadedFileReferences(to: &payload)
        appendContentSummariserSourceMetadata(to: &payload, definition: definition)

        return payload
    }

    private func validationError(definition: AgentDefinition, submissionPayload: [String: String]) -> String? {
        if definition.id == "content-summariser" {
            let hasSourceText = !(submissionPayload["url"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            let hasUploadedFiles = !(submissionPayload["uploadedFilesManifest"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty

            if !hasSourceText && !hasUploadedFiles {
                return "Provide at least one source: URL, text content, or uploaded files."
            }
        }

        if definition.id == "project-health" {
            let path = (submissionPayload["projectPath"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if path.isEmpty {
                return "Please choose a project folder."
            }

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            if !exists || !isDirectory.boolValue {
                return "Selected project path is invalid. Please choose an existing folder."
            }
        }

        for field in definition.inputSchema.fields where field.required {
            let value = (submissionPayload[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                return "Please fill required field: \(field.label)"
            }
        }

        return nil
    }

    private func appendUploadedFileReferences(to payload: inout [String: String]) {
        guard !uploadedFiles.isEmpty else { return }

        payload["uploadedFiles"] = uploadedFiles.map(\ .name).joined(separator: ", ")
        payload["uploadedFilePaths"] = uploadedFiles.map { $0.url.path }.joined(separator: ", ")
        payload["uploadedFilesManifest"] = uploadedFiles
            .map { file in
                let escapedPath = file.url.path.replacingOccurrences(of: "|", with: "%7C")
                return "\(file.name)|\(file.type)|\(file.sizeBytes)|\(escapedPath)"
            }
            .joined(separator: "\n")
    }

    private func appendContentSummariserSourceMetadata(to payload: inout [String: String], definition: AgentDefinition) {
        guard definition.id == "content-summariser" else { return }

        let sourceInputValue = (payload["url"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceInputKind = isLikelyURL(sourceInputValue) ? "url" : "text"
        let hasSourceInput = !sourceInputValue.isEmpty
        let hasFiles = !uploadedFiles.isEmpty

        let sourceKinds: [String] = [
            hasSourceInput ? sourceInputKind : "",
            hasFiles ? "files" : ""
        ].filter { !$0.isEmpty }

        let sourceKind = sourceKinds.count > 1
            ? "mixed"
            : (sourceKinds.first ?? "unknown")

        payload["sourceKind"] = sourceKind
        payload["sourceCount"] = "\(sourceKinds.count)"

        switch sourceKind {
        case "url":
            payload["sourceSummary"] = sourceInputValue
        case "files":
            payload["sourceSummary"] = "\(uploadedFiles.count) file(s)"
        case "text":
            payload["sourceSummary"] = "text content"
        case "mixed":
            payload["sourceSummary"] = sourceKinds.joined(separator: " + ")
        default:
            payload["sourceSummary"] = "no source provided"
        }

        if hasSourceInput {
            payload["sourceInput"] = sourceInputValue
        }

        if hasFiles {
            payload["sourceFileCount"] = "\(uploadedFiles.count)"
        }
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

    private func isLikelyURL(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if let components = URLComponents(string: trimmed),
           let scheme = components.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           components.host?.isEmpty == false {
            return true
        }

        return trimmed.lowercased().hasPrefix("www.")
    }
}
