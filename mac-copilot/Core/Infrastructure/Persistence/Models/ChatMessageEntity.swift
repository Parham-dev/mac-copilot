import Foundation
import SwiftData

@Model
final class ChatMessageEntity {
    @Attribute(.unique) var id: UUID
    var chatID: UUID
    var roleRaw: String
    var text: String
    var metadataJSON: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var chat: ChatThreadEntity?

    init(id: UUID, chatID: UUID, roleRaw: String, text: String, metadataJSON: String? = nil, createdAt: Date = .now, chat: ChatThreadEntity?) {
        self.id = id
        self.chatID = chatID
        self.roleRaw = roleRaw
        self.text = text
        self.metadataJSON = metadataJSON
        self.createdAt = createdAt
        self.chat = chat
    }
}