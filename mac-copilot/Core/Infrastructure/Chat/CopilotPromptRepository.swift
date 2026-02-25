import Foundation

final class CopilotPromptRepository: PromptStreamingRepository {
    private let apiService: CopilotAPIService

    init(apiService: CopilotAPIService) {
        self.apiService = apiService
    }

    func streamPrompt(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        apiService.streamPrompt(prompt)
    }
}
