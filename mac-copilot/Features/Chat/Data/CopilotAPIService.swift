import Foundation

struct CopilotModelCatalogItem: Identifiable, Hashable {
    let id: String
    let name: String
    let maxContextWindowTokens: Int?
    let maxPromptTokens: Int?
    let supportsVision: Bool
    let supportsReasoningEffort: Bool
    let policyState: String?
    let policyTerms: String?
    let billingMultiplier: Double?
    let supportedReasoningEfforts: [String]
    let defaultReasoningEffort: String?
}

final class CopilotAPIService {
    private let modelCatalogClient: CopilotModelCatalogClient
    private let promptStreamClient: CopilotPromptStreamClient

    init(baseURL: URL = URL(string: "http://127.0.0.1:7878")!) {
        self.modelCatalogClient = CopilotModelCatalogClient(baseURL: baseURL)
        self.promptStreamClient = CopilotPromptStreamClient(baseURL: baseURL)
    }

    func fetchModels() async -> [String] {
        let catalog = await fetchModelCatalog()
        let ids = catalog.map(\.id)
        return ids.isEmpty ? ["gpt-5"] : ids
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        await modelCatalogClient.fetchModelCatalog()
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        promptStreamClient.streamPrompt(prompt, chatID: chatID, model: model, projectPath: projectPath, allowedTools: allowedTools)
    }
}
