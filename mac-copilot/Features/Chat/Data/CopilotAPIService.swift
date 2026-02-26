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
        transport: HTTPDataTransporting? = nil,
        lineStreamTransport: HTTPLineStreamTransporting? = nil,
        delayScheduler: AsyncDelayScheduling? = nil
    ) {
        let resolvedTransport = transport ?? URLSessionHTTPDataTransport()
        let resolvedLineStreamTransport = lineStreamTransport ?? URLSessionHTTPLineStreamTransport()
        let resolvedDelayScheduler = delayScheduler ?? TaskAsyncDelayScheduler()

        self.modelCatalogClient = CopilotModelCatalogClient(
            baseURL: baseURL,
            ensureSidecarRunning: ensureSidecarRunning,
            transport: resolvedTransport,
            delayScheduler: resolvedDelayScheduler
        )
        self.promptStreamClient = CopilotPromptStreamClient(
            baseURL: baseURL,
            ensureSidecarRunning: ensureSidecarRunning,
            lineStreamTransport: resolvedLineStreamTransport,
            delayScheduler: resolvedDelayScheduler
        )
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        await modelCatalogClient.fetchModelCatalog()
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        promptStreamClient.streamPrompt(prompt, chatID: chatID, model: model, projectPath: projectPath, allowedTools: allowedTools)
    }
}
