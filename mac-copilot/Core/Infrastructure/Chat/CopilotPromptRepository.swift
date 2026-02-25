import Foundation

final class CopilotPromptRepository: PromptStreamingRepository, ModelListingRepository {
    private let apiService: CopilotAPIService

    init(apiService: CopilotAPIService) {
        self.apiService = apiService
    }

    func streamPrompt(_ prompt: String, model: String?) -> AsyncThrowingStream<String, Error> {
        apiService.streamPrompt(prompt, model: model)
    }

    func fetchModels() async -> [String] {
        await apiService.fetchModels()
    }
}
