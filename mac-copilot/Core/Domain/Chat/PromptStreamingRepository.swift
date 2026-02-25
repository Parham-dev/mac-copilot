import Foundation

protocol PromptStreamingRepository {
    func streamPrompt(_ prompt: String, model: String?) -> AsyncThrowingStream<String, Error>
}
