import Foundation

struct PromptToolExecutionEvent: Equatable {
    let toolName: String
    let success: Bool
    let details: String?
}

enum PromptStreamEvent: Equatable {
    case textDelta(String)
    case status(String)
    case toolExecution(PromptToolExecutionEvent)
    case completed
}

protocol PromptStreamingRepository {
    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error>
}
