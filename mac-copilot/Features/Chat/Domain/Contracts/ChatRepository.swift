import Foundation

@MainActor
protocol ChatRepository {
    func fetchChats(projectID: UUID) -> [ChatThreadRef]

    @discardableResult
    func createChat(projectID: UUID, title: String) throws -> ChatThreadRef

    func deleteChat(chatID: UUID) throws
    func updateChatTitle(chatID: UUID, title: String) throws

    func loadMessages(chatID: UUID) -> [ChatMessage]
    func saveMessage(chatID: UUID, message: ChatMessage) throws
    func updateMessage(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) throws
}