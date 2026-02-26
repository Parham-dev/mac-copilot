import Foundation
import Testing
@testable import mac_copilot

@MainActor
struct ChatViewModelPhase2Tests {
    @Test func loadModels_appliesPreferredVisibilityAndSelectionFallback() async {
        let modelRepo = FakeModelListingRepository(
            models: ["gpt-5", "claude-opus-4", "gemini-3-pro"],
            catalog: [
                CopilotModelCatalogItem(id: "gpt-5", name: "GPT-5", maxContextWindowTokens: nil, maxPromptTokens: nil, supportsVision: true, supportsReasoningEffort: true, policyState: nil, policyTerms: nil, billingMultiplier: nil, supportedReasoningEfforts: [], defaultReasoningEffort: nil),
                CopilotModelCatalogItem(id: "claude-opus-4", name: "Claude", maxContextWindowTokens: nil, maxPromptTokens: nil, supportsVision: false, supportsReasoningEffort: true, policyState: nil, policyTerms: nil, billingMultiplier: nil, supportedReasoningEfforts: [], defaultReasoningEffort: nil)
            ]
        )
        let modelStore = ModelSelectionStore(preferencesStore: InMemoryModelSelectionPreferencesStore(["claude-opus-4"]))

        let viewModel = makeViewModel(modelRepo: modelRepo, modelSelectionStore: modelStore)
        viewModel.selectedModel = "missing-model"

        await viewModel.loadModelsIfNeeded(forceReload: true)

        #expect(viewModel.availableModels == ["claude-opus-4"])
        #expect(viewModel.selectedModel == "claude-opus-4")
        #expect(viewModel.modelCatalogByID["gpt-5"] != nil)
    }

    @Test func loadModels_clearsSelectionWhenFetchReturnsEmpty() async {
        let modelRepo = FakeModelListingRepository(models: [], catalog: [])
        let viewModel = makeViewModel(modelRepo: modelRepo)
        viewModel.selectedModel = "gpt-5"

        await viewModel.loadModelsIfNeeded(forceReload: true)

        #expect(viewModel.availableModels.isEmpty)
        #expect(viewModel.selectedModel.isEmpty)
    }

    @Test func send_successfulStreamPersistsAssistantMetadataAndToolEvents() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .status("Planning"),
                .toolExecution(PromptToolExecutionEvent(toolName: "read_file", success: true, details: "opened")),
                .textDelta("Hello"),
                .textDelta(" world"),
                .completed
            ]
        )

        let chatRepo = InMemoryChatRepository()
        let viewModel = makeViewModel(promptRepo: promptRepo, chatRepo: chatRepo)
        viewModel.draftPrompt = "  build feature  "

        await viewModel.send()

        #expect(!viewModel.isSending)
        #expect(viewModel.streamingAssistantMessageID == nil)
        #expect(viewModel.draftPrompt.isEmpty)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].text == "build feature")
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].text == "Hello world")

        let assistantID = viewModel.messages[1].id
        let chips = viewModel.statusChipsByMessageID[assistantID] ?? []
        #expect(chips == ["Queued", "Planning", "Completed"])

        let tools = viewModel.toolExecutionsByMessageID[assistantID] ?? []
        #expect(tools.count == 1)
        #expect(tools.first?.toolName == "read_file")
        #expect(tools.first?.success == true)

        #expect(promptRepo.lastRequest?.prompt == "build feature")
        #expect(promptRepo.lastRequest?.allowedTools == nil)

        let persisted = try? #require(chatRepo.updatedMessages[assistantID])
        #expect(persisted?.text == "Hello world")
        #expect(persisted?.metadata?.statusChips == ["Queued", "Planning", "Completed"])
        #expect((persisted?.metadata?.toolExecutions.count ?? 0) == 1)
    }

    @Test func send_failureMarksFailedAndWritesErrorMessage() async {
        let promptRepo = FakePromptStreamingRepository(error: PromptStreamError(message: "Boom"))
        let chatRepo = InMemoryChatRepository()
        let viewModel = makeViewModel(promptRepo: promptRepo, chatRepo: chatRepo)

        await viewModel.send(prompt: "test")

        #expect(!viewModel.isSending)
        #expect(viewModel.messages.count == 2)
        let assistant = viewModel.messages[1]
        #expect(assistant.text.contains("Error:"))
        let chips = viewModel.statusChipsByMessageID[assistant.id] ?? []
        #expect(chips == ["Queued", "Failed"])

        let persisted = try? #require(chatRepo.updatedMessages[assistant.id])
        #expect(persisted?.text.contains("Error:") == true)
    }

    @Test func send_usesAllowedToolsSubsetWhenNotAllEnabled() async {
        let promptRepo = FakePromptStreamingRepository(streamEvents: [.textDelta("ok")])
        let toolStore = MCPToolsStore(preferencesStore: InMemoryMCPToolsPreferencesStore(["read_file", "list_dir"]))
        let viewModel = makeViewModel(promptRepo: promptRepo, mcpToolsStore: toolStore)

        await viewModel.send(prompt: "test")

        #expect(promptRepo.lastRequest?.allowedTools == ["list_dir", "read_file"])
    }
}

@MainActor
private func makeViewModel(
    promptRepo: FakePromptStreamingRepository = FakePromptStreamingRepository(streamEvents: [.textDelta("ok")]),
    modelRepo: FakeModelListingRepository = FakeModelListingRepository(models: ["gpt-5"], catalog: []),
    modelSelectionStore: ModelSelectionStore? = nil,
    mcpToolsStore: MCPToolsStore? = nil,
    chatRepo: InMemoryChatRepository? = nil
) -> ChatViewModel {
    let resolvedModelSelectionStore = modelSelectionStore ?? ModelSelectionStore(preferencesStore: InMemoryModelSelectionPreferencesStore([]))
    let resolvedMCPToolsStore = mcpToolsStore ?? MCPToolsStore(preferencesStore: InMemoryMCPToolsPreferencesStore([]))
    let resolvedChatRepo = chatRepo ?? InMemoryChatRepository()

    return ChatViewModel(
        chatID: UUID(),
        chatTitle: "Test Chat",
        projectPath: "/tmp/project",
        sendPromptUseCase: SendPromptUseCase(repository: promptRepo),
        fetchModelsUseCase: FetchModelsUseCase(repository: modelRepo),
        fetchModelCatalogUseCase: FetchModelCatalogUseCase(repository: modelRepo),
        modelSelectionStore: resolvedModelSelectionStore,
        mcpToolsStore: resolvedMCPToolsStore,
        chatRepository: resolvedChatRepo
    )
}

private final class FakePromptStreamingRepository: PromptStreamingRepository {
    struct Request {
        let prompt: String
        let chatID: UUID
        let model: String?
        let projectPath: String?
        let allowedTools: [String]?
    }

    private let streamEvents: [PromptStreamEvent]
    private let error: Error?
    private(set) var lastRequest: Request?

    init(streamEvents: [PromptStreamEvent] = [], error: Error? = nil) {
        self.streamEvents = streamEvents
        self.error = error
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        lastRequest = Request(prompt: prompt, chatID: chatID, model: model, projectPath: projectPath, allowedTools: allowedTools)

        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }

            for event in streamEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

private final class FakeModelListingRepository: ModelListingRepository {
    private let models: [String]
    private let catalog: [CopilotModelCatalogItem]

    init(models: [String], catalog: [CopilotModelCatalogItem]) {
        self.models = models
        self.catalog = catalog
    }

    func fetchModels() async -> [String] {
        models
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        catalog
    }
}

@MainActor
private final class InMemoryChatRepository: ChatRepository {
    private(set) var chatsByProject: [UUID: [ChatThreadRef]] = [:]
    private(set) var messagesByChat: [UUID: [ChatMessage]] = [:]
    private(set) var updatedMessages: [UUID: (text: String, metadata: ChatMessage.Metadata?)] = [:]

    func fetchChats(projectID: UUID) -> [ChatThreadRef] {
        chatsByProject[projectID] ?? []
    }

    @discardableResult
    func createChat(projectID: UUID, title: String) -> ChatThreadRef {
        let thread = ChatThreadRef(id: UUID(), projectID: projectID, title: title, createdAt: Date())
        chatsByProject[projectID, default: []].append(thread)
        return thread
    }

    func deleteChat(chatID: UUID) {
        for key in chatsByProject.keys {
            chatsByProject[key]?.removeAll(where: { $0.id == chatID })
        }
        messagesByChat.removeValue(forKey: chatID)
    }

    func loadMessages(chatID: UUID) -> [ChatMessage] {
        messagesByChat[chatID] ?? []
    }

    func saveMessage(chatID: UUID, message: ChatMessage) {
        messagesByChat[chatID, default: []].append(message)
    }

    func updateMessage(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) {
        updatedMessages[messageID] = (text, metadata)

        guard var messages = messagesByChat[chatID],
              let idx = messages.firstIndex(where: { $0.id == messageID })
        else {
            return
        }

        messages[idx].text = text
        messages[idx].metadata = metadata
        messagesByChat[chatID] = messages
    }
}

private final class InMemoryModelSelectionPreferencesStore: ModelSelectionPreferencesStoring {
    private var ids: [String]

    init(_ ids: [String]) {
        self.ids = ids
    }

    func readSelectedModelIDs() -> [String] {
        ids
    }

    func writeSelectedModelIDs(_ ids: [String]) {
        self.ids = ids
    }
}

private final class InMemoryMCPToolsPreferencesStore: MCPToolsPreferencesStoring {
    private var ids: [String]

    init(_ ids: [String]) {
        self.ids = ids
    }

    func readEnabledMCPToolIDs() -> [String] {
        ids
    }

    func writeEnabledMCPToolIDs(_ ids: [String]) {
        self.ids = ids
    }
}
