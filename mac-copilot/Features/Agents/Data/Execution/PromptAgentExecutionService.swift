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
        projectPath: String?,
        onProgress: ((String) -> Void)?
    ) async throws -> AgentExecutionOutput {
        onProgress?("Preparing request…")
        let executionContext = buildExecutionContext(definition: definition, inputPayload: inputPayload)
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
            executionContext: executionContext,
            onStreamEvent: { event in
                switch event {
                case .status(let status):
                    onProgress?(status)
                case .toolExecution(let tool):
                    onProgress?("Tool \(tool.success ? "done" : "failed"): \(tool.toolName)")
                case .completed:
                    onProgress?("Finalizing response…")
                case .textDelta:
                    break
                }
            }
        )

        let requiredContract = executionContext.requiredContract?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let requiresJSONContract = requiredContract == "json"

        if !requiresJSONContract {
            let split = splitStructuredCompanion(from: primary.finalText)

            return AgentExecutionOutput(
                finalText: split.displayText,
                statuses: primary.statuses,
                toolEvents: primary.toolEvents,
                structured: split.structured ?? AgentRunResultParser.parse(from: primary.finalText)
            )
        }

        if let parsed = AgentRunResultParser.parse(from: primary.finalText) {
            return AgentExecutionOutput(
                finalText: primary.finalText,
                statuses: primary.statuses,
                toolEvents: primary.toolEvents,
                structured: parsed
            )
        }

        let repairPrompt = buildRepairPrompt(invalidOutput: primary.finalText)
        NSLog(
            "[CopilotForge][AgentsExecution] repair stage model=%@ projectPath=%@ allowedTools=<none> requiredContract=%@",
            model ?? "<none>",
            projectPath ?? "<none>",
            requiredContract
        )

        let repaired = try await consumeStream(
            prompt: repairPrompt,
            model: model,
            projectPath: projectPath,
            allowedTools: [],
            executionContext: executionContext,
            onStreamEvent: { event in
                switch event {
                case .status(let status):
                    onProgress?(status)
                case .toolExecution(let tool):
                    onProgress?("Tool \(tool.success ? "done" : "failed"): \(tool.toolName)")
                case .completed:
                    onProgress?("Finalizing response…")
                case .textDelta:
                    break
                }
            }
        )

        return AgentExecutionOutput(
            finalText: repaired.finalText,
            statuses: primary.statuses + ["repair_attempted"] + repaired.statuses,
            toolEvents: primary.toolEvents,
            structured: AgentRunResultParser.parse(from: repaired.finalText)
        )
    }
}


