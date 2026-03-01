import Foundation
import Combine

@MainActor
final class AgentsEnvironment: ObservableObject {
    @Published private(set) var definitions: [AgentDefinition]
    @Published private(set) var runs: [AgentRun] = []
    @Published private(set) var availableModels: [String] = []
    @Published var selectedModelID: String = ""
    @Published private(set) var isLoadingModels = false
    @Published private(set) var modelLoadErrorMessage: String?

    private let fetchDefinitionsUseCase: FetchAgentDefinitionsUseCase
    private let fetchRunsUseCase: FetchAgentRunsUseCase
    private let createRunUseCase: CreateAgentRunUseCase
    private let updateRunUseCase: UpdateAgentRunUseCase
    private let deleteRunUseCase: DeleteAgentRunUseCase
    private let executionService: AgentExecutionServing
    private let fetchModelCatalogUseCase: FetchModelCatalogUseCase
    private let modelSelectionStore: ModelSelectionStore

    init(
        fetchDefinitionsUseCase: FetchAgentDefinitionsUseCase,
        fetchRunsUseCase: FetchAgentRunsUseCase,
        createRunUseCase: CreateAgentRunUseCase,
        updateRunUseCase: UpdateAgentRunUseCase,
        deleteRunUseCase: DeleteAgentRunUseCase,
        executionService: AgentExecutionServing,
        fetchModelCatalogUseCase: FetchModelCatalogUseCase,
        modelSelectionStore: ModelSelectionStore
    ) {
        self.fetchDefinitionsUseCase = fetchDefinitionsUseCase
        self.fetchRunsUseCase = fetchRunsUseCase
        self.createRunUseCase = createRunUseCase
        self.updateRunUseCase = updateRunUseCase
        self.deleteRunUseCase = deleteRunUseCase
        self.executionService = executionService
        self.fetchModelCatalogUseCase = fetchModelCatalogUseCase
        self.modelSelectionStore = modelSelectionStore
        self.definitions = fetchDefinitionsUseCase.execute()
    }

    func loadModels() async {
        guard availableModels.isEmpty else { return }

        isLoadingModels = true
        modelLoadErrorMessage = nil
        defer { isLoadingModels = false }

        do {
            let catalog = try await fetchModelCatalogUseCase.execute()
            let fetchedModels = catalog.map(\.id)

            let preferredVisible = Set(modelSelectionStore.selectedModelIDs())
            let visibleModels = preferredVisible.isEmpty
                ? fetchedModels
                : fetchedModels.filter { preferredVisible.contains($0) }

            availableModels = visibleModels.isEmpty ? fetchedModels : visibleModels

            if selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedModelID = availableModels.first ?? ""
            }

            if availableModels.isEmpty {
                modelLoadErrorMessage = "No models are currently available."
            }
        } catch {
            availableModels = []
            selectedModelID = ""
            if let catalogError = error as? CopilotModelCatalogError {
                modelLoadErrorMessage = UserFacingErrorMapper.message(catalogError, fallback: "Could not load models right now.")
            } else {
                modelLoadErrorMessage = UserFacingErrorMapper.message(error, fallback: "Could not load models right now.")
            }
        }
    }

    func loadDefinitions() {
        definitions = fetchDefinitionsUseCase.execute()
    }

    func loadRuns(projectID: UUID? = nil, agentID: String? = nil) {
        do {
            runs = try fetchRunsUseCase.execute(projectID: projectID, agentID: agentID)
        } catch {
            NSLog("[CopilotForge][AgentsEnvironment] loadRuns failed: %@", error.localizedDescription)
        }
    }

    func definition(id: String) -> AgentDefinition? {
        definitions.first(where: { $0.id == id })
    }

    @discardableResult
    func createRun(agentID: String, projectID: UUID?, inputPayload: [String: String]) throws -> AgentRun {
        let run = AgentRun(
            agentID: agentID,
            projectID: projectID,
            inputPayload: inputPayload,
            status: .queued,
            startedAt: .now
        )

        let created = try createRunUseCase.execute(run: run)
        runs.insert(created, at: 0)
        return created
    }

    func updateRun(_ run: AgentRun) throws {
        try updateRunUseCase.execute(run: run)

        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
        }
    }

    func deleteRun(id: UUID, projectID: UUID? = nil, agentID: String? = nil) throws {
        try deleteRunUseCase.execute(runID: id)
        runs.removeAll { $0.id == id }
        loadRuns(projectID: projectID, agentID: agentID)
    }

    @discardableResult
    func executeRun(
        definition: AgentDefinition,
        projectID: UUID?,
        inputPayload: [String: String],
        model: String? = nil,
        projectPath: String? = nil,
        onProgress: ((String) -> Void)? = nil
    ) async throws -> AgentRun {
        let queued = try createRun(
            agentID: definition.id,
            projectID: projectID,
            inputPayload: inputPayload
        )

        var running = queued
        running.status = .running
        try updateRun(running)

        do {
            let output = try await executionService.execute(
                definition: definition,
                inputPayload: inputPayload,
                model: model,
                projectPath: projectPath,
                onProgress: onProgress
            )

            var completed = running
            completed.streamedOutput = output.finalText
            completed.completedAt = .now
            let requestedURL = inputPayload["url"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let requiresFetchMCP = shouldRequireFetchMCP(for: definition, requestedURL: requestedURL)
            let fetchMCPToolEvents = output.toolEvents.filter { isFetchMCPTool($0.toolName) }
            let hasSuccessfulFetchMCP = output.toolEvents.contains { event in
                isFetchMCPTool(event.toolName) && event.success
            }
            let hasSuccessfulURLFetch = output.toolEvents.contains { event in
                (isFetchMCPTool(event.toolName)
                || isNativeWebFetchTool(event.toolName)) && event.success
            }

            completed.diagnostics = AgentRunDiagnostics(
                toolTraces: output.toolEvents.map { event in
                    let details = event.details ?? ""
                    return "\(event.toolName): \(event.success ? "success" : "failed") \(details)"
                },
                warnings: []
            )

            if output.toolEvents.isEmpty {
                completed.diagnostics.warnings.append("no_tool_execution_detected")
                NSLog(
                    "[CopilotForge][AgentsEnvironment] no tool execution detected agentID=%@ runID=%@",
                    definition.id,
                    completed.id.uuidString
                )
            }

            if !requestedURL.isEmpty {
                if fetchMCPToolEvents.isEmpty {
                    NSLog(
                        "[CopilotForge][AgentsEnvironment] fetch mcp not used agentID=%@ runID=%@ requestedURL=%@ observedTools=%@",
                        definition.id,
                        completed.id.uuidString,
                        requestedURL,
                        output.toolEvents.map(\ .toolName).joined(separator: ",")
                    )
                } else if let failedFetchMCP = fetchMCPToolEvents.first(where: { !$0.success }) {
                    NSLog(
                        "[CopilotForge][AgentsEnvironment] fetch mcp failed agentID=%@ runID=%@ tool=%@ details=%@",
                        definition.id,
                        completed.id.uuidString,
                        failedFetchMCP.toolName,
                        failedFetchMCP.details ?? "<no-details>"
                    )
                }
            }

            let missingRequiredFetch = requiresFetchMCP ? !hasSuccessfulFetchMCP : !hasSuccessfulURLFetch

            if !requestedURL.isEmpty, missingRequiredFetch {
                completed.status = .failed
                completed.finalOutput = nil
                completed.diagnostics.warnings.append("url_fetch_required_but_not_executed")
                if requiresFetchMCP {
                    completed.diagnostics.warnings.append("fetch_mcp_required_for_url_agent")
                }
                NSLog(
                    "[CopilotForge][AgentsEnvironment] url fetch missing (%@) for URL agentID=%@ runID=%@ url=%@",
                    requiresFetchMCP ? "fetch" : "fetch/web_fetch/fetch_webpage",
                    definition.id,
                    completed.id.uuidString,
                    requestedURL
                )
                try updateRun(completed)
                loadRuns(projectID: projectID, agentID: definition.id)
                return completed
            }

            let requestedOutputMode = normalizedOutputMode(inputPayload["outputFormat"])
            let requiresJSONContract = requestedOutputMode == "json"

            if requiresJSONContract {
                switch AgentRunResultParser.parseDetailed(from: output.finalText) {
                case .success(let parsed):
                    completed.status = .completed
                    completed.finalOutput = AgentRunResultParser.encodePretty(parsed)
                case .failure(let parseError):
                    completed.status = .failed
                    completed.finalOutput = nil
                    completed.diagnostics.warnings.append("schema_parse_failed")
                    completed.diagnostics.warnings.append(parseError.localizedDescription)

                    NSLog(
                        "[CopilotForge][AgentsEnvironment] schema validation failed agentID=%@ runID=%@ reason=%@ outputPreview=%@",
                        definition.id,
                        completed.id.uuidString,
                        parseError.localizedDescription,
                        String(output.finalText.prefix(800))
                    )
                }
            } else {
                completed.status = .completed
                completed.finalOutput = output.finalText
            }

            try updateRun(completed)
            loadRuns(projectID: projectID, agentID: definition.id)
            return completed
        } catch {
            var failed = running
            failed.status = .failed
            failed.completedAt = .now
            failed.diagnostics.warnings.append("execution_failed")
            failed.diagnostics.warnings.append(error.localizedDescription)

            NSLog(
                "[CopilotForge][AgentsEnvironment] executeRun failed agentID=%@ runID=%@ error=%@",
                definition.id,
                failed.id.uuidString,
                error.localizedDescription
            )

            try updateRun(failed)
            loadRuns(projectID: projectID, agentID: definition.id)
            throw error
        }
    }
}

private extension AgentsEnvironment {
    func normalizedOutputMode(_ rawValue: String?) -> String {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if value.isEmpty {
            return "text"
        }

        switch value {
        case "markdown", "markdown brief":
            return "markdown"
        case "json":
            return "json"
        case "table":
            return "table"
        case "text", "bullet":
            return "text"
        default:
            return "text"
        }
    }
}
