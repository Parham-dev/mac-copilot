import Foundation

@MainActor
protocol ChatRepository {
    func fetchChats(projectID: UUID) -> [ChatThreadRef]

    @discardableResult
    func createChat(projectID: UUID, title: String) throws -> ChatThreadRef

    func deleteChat(chatID: UUID)
    func updateChatTitle(chatID: UUID, title: String)

    func loadMessages(chatID: UUID) -> [ChatMessage]
    func saveMessage(chatID: UUID, message: ChatMessage)
    func updateMessage(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?)
}