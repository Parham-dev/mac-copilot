import Foundation
import SwiftData

@MainActor
final class SwiftDataChatRepository: ChatRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchChats(projectID: UUID) -> [ChatThreadRef] {
        let predicateProjectID = projectID
        let descriptor = FetchDescriptor<ChatThreadEntity>(
            predicate: #Predicate { $0.projectID == predicateProjectID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }

        return entities.map {
            ChatThreadRef(id: $0.id, projectID: $0.projectID, title: $0.title, createdAt: $0.createdAt)
        }
    }

    @discardableResult
    func createChat(projectID: UUID, title: String) -> ChatThreadRef {
        let ref = ChatThreadRef(projectID: projectID, title: title)
        let entity = ChatThreadEntity(id: ref.id, projectID: ref.projectID, title: ref.title, createdAt: ref.createdAt, project: findProjectEntity(id: projectID))
        context.insert(entity)
        try? context.save()
        return ref
    }

    func loadMessages(chatID: UUID) -> [ChatMessage] {
        let predicateChatID = chatID
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.chatID == predicateChatID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }

        return entities.compactMap { entity in
            guard let role = ChatMessage.Role(rawValue: entity.roleRaw) else {
                return nil
            }
            return ChatMessage(id: entity.id, role: role, text: entity.text, createdAt: entity.createdAt)
        }
    }

    func saveMessage(chatID: UUID, message: ChatMessage) {
        let entity = ChatMessageEntity(
            id: message.id,
            chatID: chatID,
            roleRaw: message.role.rawValue,
            text: message.text,
            createdAt: message.createdAt,
            chat: findChatEntity(id: chatID)
        )
        context.insert(entity)
        try? context.save()
    }

    func updateMessage(chatID: UUID, messageID: UUID, text: String) {
        let predicateMessageID = messageID
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.id == predicateMessageID }
        )

        guard let entity = (try? context.fetch(descriptor))?.first else {
            return
        }

        entity.chatID = chatID
        entity.text = text
        try? context.save()
    }

    private func findProjectEntity(id: UUID) -> ProjectEntity? {
        let predicateProjectID = id
        let descriptor = FetchDescriptor<ProjectEntity>(
            predicate: #Predicate { $0.id == predicateProjectID }
        )

        return try? context.fetch(descriptor).first
    }

    private func findChatEntity(id: UUID) -> ChatThreadEntity? {
        let predicateChatID = id
        let descriptor = FetchDescriptor<ChatThreadEntity>(
            predicate: #Predicate { $0.id == predicateChatID }
        )

        return try? context.fetch(descriptor).first
    }
}