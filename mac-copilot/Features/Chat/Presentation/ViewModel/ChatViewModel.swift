import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published var isSending = false
    @Published var messages: [ChatMessage]
    @Published var statusChipsByMessageID: [UUID: [String]] = [:]
    @Published var toolExecutionsByMessageID: [UUID: [ChatMessage.ToolExecution]] = [:]
    @Published var inlineSegmentsByMessageID: [UUID: [AssistantTranscriptSegment]] = [:]
    @Published var streamingAssistantMessageID: UUID?
    @Published var availableModels: [String] = []
    @Published var selectedModel = ""
    @Published var modelCatalogErrorMessage: String?
    @Published var messagePersistenceErrorMessage: String?

    let chatID: UUID
    @Published var chatTitle: String
    let projectPath: String

    let sendPromptUseCase: SendPromptUseCase
    let fetchModelCatalogUseCase: FetchModelCatalogUseCase
    let modelSelectionStore: ModelSelectionStore
    let nativeToolsStore: NativeToolsStore
    let chatEventsStore: ChatEventsStore
    let sessionCoordinator: ChatSessionCoordinator
    var modelCatalogByID: [String: CopilotModelCatalogItem] = [:]

    init(
        chatID: UUID,
        chatTitle: String,
        projectPath: String,
        sendPromptUseCase: SendPromptUseCase,
        fetchModelCatalogUseCase: FetchModelCatalogUseCase,
        modelSelectionStore: ModelSelectionStore,
        nativeToolsStore: NativeToolsStore,
        chatRepository: ChatRepository,
        chatEventsStore: ChatEventsStore
    ) {
        self.chatID = chatID
        self.chatTitle = chatTitle
        self.projectPath = projectPath
        self.sendPromptUseCase = sendPromptUseCase
        self.fetchModelCatalogUseCase = fetchModelCatalogUseCase
        self.modelSelectionStore = modelSelectionStore
        self.nativeToolsStore = nativeToolsStore
        self.chatEventsStore = chatEventsStore
        self.sessionCoordinator = ChatSessionCoordinator(chatRepository: chatRepository)
        let bootstrappedMessages: [ChatMessage]
        do {
            bootstrappedMessages = try sessionCoordinator.bootstrapMessages(chatID: chatID)
        } catch {
            bootstrappedMessages = []
            self.messagePersistenceErrorMessage = "Some local chat history is unavailable right now."
        }
        self.messages = bootstrappedMessages
        hydrateMetadata(from: bootstrappedMessages)
    }

    func clearModelCatalogErrorMessage() {
        modelCatalogErrorMessage = nil
    }

    func clearMessagePersistenceErrorMessage() {
        messagePersistenceErrorMessage = nil
    }
}
