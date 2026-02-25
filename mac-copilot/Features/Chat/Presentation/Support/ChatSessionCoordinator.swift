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
}
