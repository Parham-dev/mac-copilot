import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published private(set) var isSending = false
    @Published private(set) var messages: [ChatMessage]
    @Published private(set) var statusChipsByMessageID: [UUID: [String]] = [:]
    @Published private(set) var toolExecutionsByMessageID: [UUID: [ChatMessage.ToolExecution]] = [:]
    @Published private(set) var streamingAssistantMessageID: UUID?
    @Published private(set) var availableModels: [String] = ["gpt-5"]
    @Published var selectedModel = "gpt-5"

    let chatID: UUID
    let chatTitle: String
    let projectPath: String

    private let sendPromptUseCase: SendPromptUseCase
    private let fetchModelsUseCase: FetchModelsUseCase
    private let sessionCoordinator: ChatSessionCoordinator

    init(
        chatID: UUID,
        chatTitle: String,
        projectPath: String,
        sendPromptUseCase: SendPromptUseCase,
        fetchModelsUseCase: FetchModelsUseCase,
        chatRepository: ChatRepository
    ) {
        self.chatID = chatID
        self.chatTitle = chatTitle
        self.projectPath = projectPath
        self.sendPromptUseCase = sendPromptUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
        self.sessionCoordinator = ChatSessionCoordinator(chatRepository: chatRepository)
        let bootstrappedMessages = sessionCoordinator.bootstrapMessages(chatID: chatID)
        self.messages = bootstrappedMessages
        hydrateMetadata(from: bootstrappedMessages)
    }

    func loadModelsIfNeeded() async {
        if availableModels.count > 1 {
            return
        }

        let models = await fetchModelsUseCase.execute()
        if !models.isEmpty {
            availableModels = models
            if !models.contains(selectedModel) {
                selectedModel = models[0]
            }
        }
    }

    func send() async {
        let text = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        await send(prompt: text)
    }

    func send(prompt: String) async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isSending else { return }

        isSending = true
        let userMessage = sessionCoordinator.appendUserMessage(chatID: chatID, text: text)
        messages.append(userMessage)

        let assistantIndex = messages.count
        let assistantMessage = sessionCoordinator.appendAssistantPlaceholder(chatID: chatID)
        messages.append(assistantMessage)
        statusChipsByMessageID[assistantMessage.id] = ["Queued"]
        toolExecutionsByMessageID[assistantMessage.id] = []
        streamingAssistantMessageID = assistantMessage.id
        draftPrompt = ""

        do {
            var hasContent = false
            for try await event in sendPromptUseCase.execute(
                prompt: text,
                model: selectedModel,
                projectPath: projectPath
            ) {
                switch event {
                case .textDelta(let chunk):
                    hasContent = true
                    messages[assistantIndex].text += chunk
                case .status(let label):
                    appendStatus(label, for: assistantMessage.id)
                case .toolExecution(let tool):
                    appendToolExecution(tool, for: assistantMessage.id)
                case .completed:
                    appendStatus("Completed", for: assistantMessage.id)
                }
            }

            if !hasContent {
                messages[assistantIndex].text = "No response from Copilot."
            }
        } catch {
            appendStatus("Failed", for: assistantMessage.id)
            messages[assistantIndex].text = "Error: \(error.localizedDescription)"
        }

        sessionCoordinator.persistAssistantContent(
            chatID: chatID,
            messageID: assistantMessage.id,
            text: messages[assistantIndex].text,
            metadata: metadata(for: assistantMessage.id)
        )

        streamingAssistantMessageID = nil
        isSending = false
    }

    private func appendStatus(_ label: String, for messageID: UUID) {
        let current = statusChipsByMessageID[messageID] ?? []
        guard current.last != label else { return }
        statusChipsByMessageID[messageID] = current + [label]
    }

    private func appendToolExecution(_ event: PromptToolExecutionEvent, for messageID: UUID) {
        let current = toolExecutionsByMessageID[messageID] ?? []
        let entry = ChatMessage.ToolExecution(
            toolName: event.toolName,
            success: event.success,
            details: event.details
        )
        toolExecutionsByMessageID[messageID] = current + [entry]
    }

    private func metadata(for messageID: UUID) -> ChatMessage.Metadata? {
        let chips = statusChipsByMessageID[messageID] ?? []
        let tools = toolExecutionsByMessageID[messageID] ?? []
        guard !chips.isEmpty || !tools.isEmpty else {
            return nil
        }

        return ChatMessage.Metadata(statusChips: chips, toolExecutions: tools)
    }

    private func hydrateMetadata(from messages: [ChatMessage]) {
        var chipsMap: [UUID: [String]] = [:]
        var toolsMap: [UUID: [ChatMessage.ToolExecution]] = [:]

        for message in messages where message.role == .assistant {
            guard let metadata = message.metadata else { continue }

            if !metadata.statusChips.isEmpty {
                chipsMap[message.id] = metadata.statusChips
            }

            if !metadata.toolExecutions.isEmpty {
                toolsMap[message.id] = metadata.toolExecutions
            }
        }

        statusChipsByMessageID = chipsMap
        toolExecutionsByMessageID = toolsMap
    }
}
