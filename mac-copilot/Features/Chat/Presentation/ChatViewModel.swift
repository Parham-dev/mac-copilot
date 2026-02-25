import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published private(set) var isSending = false
    @Published private(set) var messages: [ChatMessage]

    let chatTitle: String

    private let sendPromptUseCase: SendPromptUseCase

    init(chatTitle: String, sendPromptUseCase: SendPromptUseCase) {
        self.chatTitle = chatTitle
        self.sendPromptUseCase = sendPromptUseCase
        self.messages = [
            ChatMessage(role: .assistant, text: "Hi! Describe the app you want to build."),
        ]
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
            for try await chunk in sendPromptUseCase.execute(prompt: text) {
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
