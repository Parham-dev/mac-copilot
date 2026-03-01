import Foundation

struct AgentExecutionOutput {
    var finalText: String
    var statuses: [String]
    var toolEvents: [PromptToolExecutionEvent]
}

@MainActor
protocol AgentExecutionServing {
    func execute(
        definition: AgentDefinition,
        inputPayload: [String: String],
        model: String?,
        projectPath: String?
    ) async throws -> AgentExecutionOutput
}
