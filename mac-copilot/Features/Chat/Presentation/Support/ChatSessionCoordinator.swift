import Foundation

@MainActor
final class ChatSessionCoordinator {
    private let chatRepository: ChatRepository

    init(chatRepository: ChatRepository) {
        self.chatRepository = chatRepository
    }

    func bootstrapMessages(chatID: UUID) throws -> [ChatMessage] {
        let existingMessages = try chatRepository.loadMessages(chatID: chatID)
        return existingMessages
    }

    @discardableResult
    func appendUserMessage(chatID: UUID, text: String) throws -> ChatMessage {
        let message = ChatMessage(role: .user, text: text)
        try chatRepository.saveMessage(chatID: chatID, message: message)
        return message
    }

    @discardableResult
    func appendAssistantPlaceholder(chatID: UUID) throws -> ChatMessage {
        let message = ChatMessage(role: .assistant, text: "")
        try chatRepository.saveMessage(chatID: chatID, message: message)
        return message
    }

    func persistAssistantContent(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) throws {
        try chatRepository.updateMessage(chatID: chatID, messageID: messageID, text: text, metadata: metadata)
    }

    func updateChatTitleFromFirstUserMessageIfNeeded(chatID: UUID, promptText: String, hadUserMessageBeforeSend: Bool) throws -> String? {
        guard !hadUserMessageBeforeSend else {
            return nil
        }

        guard let nextTitle = makeChatTitle(from: promptText) else {
            return nil
        }

        try chatRepository.updateChatTitle(chatID: chatID, title: nextTitle)
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
