import Foundation

@MainActor
final class ChatSessionCoordinator {
    private let chatRepository: ChatRepository

    init(chatRepository: ChatRepository) {
        self.chatRepository = chatRepository
    }

    func bootstrapMessages(chatID: UUID) -> [ChatMessage] {
        let existingMessages = chatRepository.loadMessages(chatID: chatID)
        return existingMessages
    }

    @discardableResult
    func appendUserMessage(chatID: UUID, text: String) -> ChatMessage {
        let message = ChatMessage(role: .user, text: text)
        chatRepository.saveMessage(chatID: chatID, message: message)
        return message
    }

    @discardableResult
    func appendAssistantPlaceholder(chatID: UUID) -> ChatMessage {
        let message = ChatMessage(role: .assistant, text: "")
        chatRepository.saveMessage(chatID: chatID, message: message)
        return message
    }

    func persistAssistantContent(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) {
        chatRepository.updateMessage(chatID: chatID, messageID: messageID, text: text, metadata: metadata)
    }

    func updateChatTitleFromFirstUserMessageIfNeeded(chatID: UUID, promptText: String, hadUserMessageBeforeSend: Bool) -> String? {
        guard !hadUserMessageBeforeSend else {
            return nil
        }

        guard let nextTitle = makeChatTitle(from: promptText) else {
            return nil
        }

        chatRepository.updateChatTitle(chatID: chatID, title: nextTitle)
        return nextTitle
    }

    private func makeChatTitle(from promptText: String) -> String? {
        let normalized = promptText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return nil
        }

        let maxLength = 48
        if normalized.count <= maxLength {
            return normalized
        }

        return String(normalized.prefix(maxLength - 3)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
