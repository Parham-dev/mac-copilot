import Foundation

protocol PromptStreamingRepository {
    func streamPrompt(_ prompt: String) -> AsyncThrowingStream<String, Error>
}
