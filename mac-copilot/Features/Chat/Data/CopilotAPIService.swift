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

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:7878")!,
        ensureSidecarRunning: @escaping () -> Void = {},
        transport: HTTPDataTransporting = URLSessionHTTPDataTransport(),
        lineStreamTransport: HTTPLineStreamTransporting = URLSessionHTTPLineStreamTransport(),
        delayScheduler: AsyncDelayScheduling = TaskAsyncDelayScheduler()
    ) {
        self.modelCatalogClient = CopilotModelCatalogClient(
            baseURL: baseURL,
            ensureSidecarRunning: ensureSidecarRunning,
            transport: transport,
            delayScheduler: delayScheduler
        )
        self.promptStreamClient = CopilotPromptStreamClient(
            baseURL: baseURL,
            ensureSidecarRunning: ensureSidecarRunning,
            lineStreamTransport: lineStreamTransport,
            delayScheduler: delayScheduler
        )
    }

    func fetchModels() async -> [String] {
        let catalog = await fetchModelCatalog()
        return catalog.map(\.id)
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        await modelCatalogClient.fetchModelCatalog()
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        promptStreamClient.streamPrompt(prompt, chatID: chatID, model: model, projectPath: projectPath, allowedTools: allowedTools)
    }
}
