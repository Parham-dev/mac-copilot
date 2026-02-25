import Foundation

final class CopilotPromptRepository: PromptStreamingRepository, ModelListingRepository {
    private let apiService: CopilotAPIService

    init(apiService: CopilotAPIService) {
        self.apiService = apiService
    }

    func streamPrompt(_ prompt: String, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        apiService.streamPrompt(prompt, model: model, projectPath: projectPath, allowedTools: allowedTools)
    }

    func fetchModels() async -> [String] {
        await apiService.fetchModels()
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        await apiService.fetchModelCatalog()
    }
}
