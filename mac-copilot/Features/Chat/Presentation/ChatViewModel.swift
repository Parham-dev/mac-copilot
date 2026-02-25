import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published private(set) var isSending = false
    @Published private(set) var messages: [ChatMessage]
    @Published private(set) var availableModels: [String] = ["gpt-5"]
    @Published var selectedModel = "gpt-5"

    let chatID: UUID
    let chatTitle: String
    let projectPath: String

    private let sendPromptUseCase: SendPromptUseCase
    private let fetchModelsUseCase: FetchModelsUseCase
    private let chatRepository: ChatRepository

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
        self.chatRepository = chatRepository

        let existingMessages = chatRepository.loadMessages(chatID: chatID)
        if existingMessages.isEmpty {
            let welcome = ChatMessage(role: .assistant, text: "Hi! Describe the app you want to build.")
            self.messages = [welcome]
            chatRepository.saveMessage(chatID: chatID, message: welcome)
        } else {
            self.messages = existingMessages
        }
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
        let userMessage = ChatMessage(role: .user, text: text)
        messages.append(userMessage)
        chatRepository.saveMessage(chatID: chatID, message: userMessage)

        let assistantIndex = messages.count
        let assistantMessage = ChatMessage(role: .assistant, text: "")
        messages.append(assistantMessage)
        chatRepository.saveMessage(chatID: chatID, message: assistantMessage)
        draftPrompt = ""

        do {
            var hasContent = false
            for try await chunk in sendPromptUseCase.execute(
                prompt: text,
                model: selectedModel,
                projectPath: projectPath
            ) {
                hasContent = true
                messages[assistantIndex].text += chunk
            }

            if !hasContent {
                messages[assistantIndex].text = "No response from Copilot."
            }
        } catch {
            messages[assistantIndex].text = "Error: \(error.localizedDescription)"
        }

        chatRepository.updateMessage(
            chatID: chatID,
            messageID: assistantMessage.id,
            text: messages[assistantIndex].text
        )

        isSending = false
    }
}
