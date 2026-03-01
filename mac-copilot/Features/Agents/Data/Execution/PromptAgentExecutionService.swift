import Foundation

@MainActor
final class PromptAgentExecutionService: AgentExecutionServing {
    let promptRepository: PromptStreamingRepository

    init(promptRepository: PromptStreamingRepository) {
        self.promptRepository = promptRepository
    }

    func execute(
        definition: AgentDefinition,
        inputPayload: [String: String],
        model: String?,
        projectPath: String?
    ) async throws -> AgentExecutionOutput {
        let executionContext = buildExecutionContext(definition: definition, inputPayload: inputPayload)
        let requestedURL = inputPayload["url"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let executionAllowedTools = allowedToolsForExecution(
            definition: definition,
            inputPayload: inputPayload
        )
        NSLog(
            "[CopilotForge][AgentsExecution] primary stage model=%@ projectPath=%@ allowedTools=%@",
            model ?? "<none>",
            projectPath ?? "<none>",
            executionAllowedTools?.joined(separator: ",") ?? "<none>"
        )
        let prompt = buildPrompt(definition: definition, inputPayload: inputPayload)
        let primary = try await consumeStream(
            prompt: prompt,
            model: model,
            projectPath: projectPath,
            allowedTools: executionAllowedTools,
            executionContext: executionContext
        )

        var candidateText = primary.finalText
        var mergedStatuses = primary.statuses
        var mergedToolEvents = primary.toolEvents

        if !requestedURL.isEmpty,
              !hasSuccessfulURLFetch(in: primary.toolEvents) {
            let forceFetchPrompt = buildForceFetchPrompt(
                definition: definition,
                inputPayload: inputPayload,
                url: requestedURL
            )

            NSLog(
                "[CopilotForge][AgentsExecution] force_fetch stage model=%@ projectPath=%@ allowedTools=%@",
                model ?? "<none>",
                projectPath ?? "<none>",
                executionAllowedTools?.joined(separator: ",") ?? "<none>"
            )

            let forced = try await consumeStream(
                prompt: forceFetchPrompt,
                model: model,
                projectPath: projectPath,
                allowedTools: executionAllowedTools,
                executionContext: executionContext
            )

            candidateText = forced.finalText
            mergedStatuses.append("fetch_retry_attempted")
            mergedStatuses.append(contentsOf: forced.statuses)
            mergedToolEvents.append(contentsOf: forced.toolEvents)
        }

        if case .success = AgentRunResultParser.parseDetailed(from: candidateText) {
            return AgentExecutionOutput(
                finalText: candidateText,
                statuses: mergedStatuses,
                toolEvents: mergedToolEvents
            )
        }

        let repairPrompt = buildRepairPrompt(invalidOutput: candidateText)
        NSLog(
            "[CopilotForge][AgentsExecution] repair stage model=%@ projectPath=%@ allowedTools=<none>",
            model ?? "<none>",
            projectPath ?? "<none>"
        )
        let repaired = try await consumeStream(
            prompt: repairPrompt,
            model: model,
            projectPath: projectPath,
            allowedTools: [],
            executionContext: executionContext
        )

        mergedStatuses.append("repair_attempted")
        mergedStatuses.append(contentsOf: repaired.statuses)

        return AgentExecutionOutput(
            finalText: repaired.finalText,
            statuses: mergedStatuses,
            toolEvents: mergedToolEvents
        )
    }
}


