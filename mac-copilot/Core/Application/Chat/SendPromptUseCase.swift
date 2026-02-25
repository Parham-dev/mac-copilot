import Foundation

struct SendPromptUseCase {
    private let repository: PromptStreamingRepository

    init(repository: PromptStreamingRepository) {
        self.repository = repository
    }

    func execute(prompt: String) -> AsyncThrowingStream<String, Error> {
        repository.streamPrompt(prompt)
    }
}
