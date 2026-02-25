import Foundation

protocol PromptStreamingRepository {
    func streamPrompt(_ prompt: String, model: String?, projectPath: String?) -> AsyncThrowingStream<String, Error>
}
