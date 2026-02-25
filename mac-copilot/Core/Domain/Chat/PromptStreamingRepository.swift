import Foundation

enum PromptStreamEvent: Equatable {
    case textDelta(String)
    case status(String)
    case completed
}

protocol PromptStreamingRepository {
    func streamPrompt(_ prompt: String, model: String?, projectPath: String?) -> AsyncThrowingStream<PromptStreamEvent, Error>
}
