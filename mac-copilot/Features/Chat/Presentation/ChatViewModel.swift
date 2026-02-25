import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published private(set) var isSending = false
    @Published private(set) var messages: [ChatMessage]
    @Published private(set) var availableModels: [String] = ["gpt-5"]
    @Published var selectedModel = "gpt-5"

    let chatTitle: String
    let projectPath: String

    private let sendPromptUseCase: SendPromptUseCase
    private let fetchModelsUseCase: FetchModelsUseCase

    init(
        chatTitle: String,
        projectPath: String,
        sendPromptUseCase: SendPromptUseCase,
        fetchModelsUseCase: FetchModelsUseCase
    ) {
        self.chatTitle = chatTitle
        self.projectPath = projectPath
        self.sendPromptUseCase = sendPromptUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
        self.messages = [
            ChatMessage(role: .assistant, text: "Hi! Describe the app you want to build."),
        ]
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
        guard !text.isEmpty else { return }
        guard !isSending else { return }

        isSending = true
        messages.append(ChatMessage(role: .user, text: text))
        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, text: ""))
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

        isSending = false
    }
}
