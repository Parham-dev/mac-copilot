import Foundation

struct PromptToolExecutionEvent: Equatable {
    let toolName: String
    let success: Bool
    let details: String?
    let input: String?
    let output: String?

    init(toolName: String, success: Bool, details: String?, input: String? = nil, output: String? = nil) {
        self.toolName = toolName
        self.success = success
        self.details = details
        self.input = input
        self.output = output
    }
}

enum PromptStreamEvent: Equatable {
    case textDelta(String)
    case status(String)
    case toolExecution(PromptToolExecutionEvent)
    case completed
}

struct PromptExecutionContext: Equatable {
    let agentID: String
    let feature: String
    let policyProfile: String
    let skillNames: [String]
    let requireSkills: Bool
    let requestedOutputMode: String?
    let requiredContract: String?
}

protocol PromptStreamingRepository {
    func streamPrompt(
        _ prompt: String,
        chatID: UUID,
        model: String?,
        projectPath: String?,
        allowedTools: [String]?,
        executionContext: PromptExecutionContext?
    ) -> AsyncThrowingStream<PromptStreamEvent, Error>
}
