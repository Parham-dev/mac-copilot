import Foundation

struct SendPromptUseCase {
    private let repository: PromptStreamingRepository

    init(repository: PromptStreamingRepository) {
        self.repository = repository
    }

    func execute(prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        repository.streamPrompt(
            prompt,
            chatID: chatID,
            model: model,
            projectPath: projectPath,
            allowedTools: allowedTools,
            executionContext: nil
        )
    }
}
