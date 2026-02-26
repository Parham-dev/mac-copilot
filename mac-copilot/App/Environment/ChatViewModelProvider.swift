import Foundation

@MainActor
final class ChatViewModelProvider {
    private let promptRepository: PromptStreamingRepository
    private let modelRepository: ModelListingRepository
    private let chatRepository: ChatRepository
    private let modelSelectionStore: ModelSelectionStore
    private let mcpToolsStore: MCPToolsStore
    private let chatEventsStore: ChatEventsStore

    private var cache: [String: ChatViewModel] = [:]

    init(
        promptRepository: PromptStreamingRepository,
        modelRepository: ModelListingRepository,
        chatRepository: ChatRepository,
        modelSelectionStore: ModelSelectionStore,
        mcpToolsStore: MCPToolsStore,
        chatEventsStore: ChatEventsStore
    ) {
        self.promptRepository = promptRepository
        self.modelRepository = modelRepository
        self.chatRepository = chatRepository
        self.modelSelectionStore = modelSelectionStore
        self.mcpToolsStore = mcpToolsStore
        self.chatEventsStore = chatEventsStore
    }

    func viewModel(for chat: ChatThreadRef, project: ProjectRef) -> ChatViewModel {
        let cacheKey = "\(project.id.uuidString)|\(chat.id.uuidString)"

        if let existing = cache[cacheKey] {
            return existing
        }

        let created = ChatViewModel(
            chatID: chat.id,
            chatTitle: chat.title,
            projectPath: project.localPath,
            sendPromptUseCase: SendPromptUseCase(repository: promptRepository),
            fetchModelCatalogUseCase: FetchModelCatalogUseCase(repository: modelRepository),
            modelSelectionStore: modelSelectionStore,
            mcpToolsStore: mcpToolsStore,
            chatRepository: chatRepository,
            chatEventsStore: chatEventsStore
        )

        cache[cacheKey] = created
        return created
    }
}
