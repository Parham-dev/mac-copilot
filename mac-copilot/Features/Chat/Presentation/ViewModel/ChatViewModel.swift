import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published var isSending = false
    @Published var messages: [ChatMessage]
    @Published var statusChipsByMessageID: [UUID: [String]] = [:]
    @Published var toolExecutionsByMessageID: [UUID: [ChatMessage.ToolExecution]] = [:]
    @Published var streamingAssistantMessageID: UUID?
    @Published var availableModels: [String] = ["gpt-5"]
    @Published var selectedModel = "gpt-5"

    let chatID: UUID
    let chatTitle: String
    let projectPath: String

    let sendPromptUseCase: SendPromptUseCase
    let fetchModelsUseCase: FetchModelsUseCase
    let fetchModelCatalogUseCase: FetchModelCatalogUseCase
    let modelSelectionStore: ModelSelectionStore
    let mcpToolsStore: MCPToolsStore
    let sessionCoordinator: ChatSessionCoordinator
    var modelCatalogByID: [String: CopilotModelCatalogItem] = [:]

    init(
        chatID: UUID,
        chatTitle: String,
        projectPath: String,
        sendPromptUseCase: SendPromptUseCase,
        fetchModelsUseCase: FetchModelsUseCase,
        fetchModelCatalogUseCase: FetchModelCatalogUseCase,
        modelSelectionStore: ModelSelectionStore,
        mcpToolsStore: MCPToolsStore,
        chatRepository: ChatRepository
    ) {
        self.chatID = chatID
        self.chatTitle = chatTitle
        self.projectPath = projectPath
        self.sendPromptUseCase = sendPromptUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
        self.fetchModelCatalogUseCase = fetchModelCatalogUseCase
        self.modelSelectionStore = modelSelectionStore
        self.mcpToolsStore = mcpToolsStore
        self.sessionCoordinator = ChatSessionCoordinator(chatRepository: chatRepository)
        let bootstrappedMessages = sessionCoordinator.bootstrapMessages(chatID: chatID)
        self.messages = bootstrappedMessages
        hydrateMetadata(from: bootstrappedMessages)
    }
}
