import Foundation

struct SendPromptUseCase {
    private let repository: PromptStreamingRepository

    init(repository: PromptStreamingRepository) {
        self.repository = repository
    }

    func execute(prompt: String, model: String?) -> AsyncThrowingStream<String, Error> {
        repository.streamPrompt(prompt, model: model)
    }
}

struct FetchModelsUseCase {
    private let repository: ModelListingRepository

    init(repository: ModelListingRepository) {
        self.repository = repository
    }

    func execute() async -> [String] {
        await repository.fetchModels()
    }
}
