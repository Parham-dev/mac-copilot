import Foundation
import SwiftData

@MainActor
final class SwiftDataChatRepository: ChatRepository {
    private enum RepositoryError: LocalizedError {
        case fetchChatsFailed(String)
        case createChatSaveFailed(String)
        case fetchMessagesFailed(String)
        case saveMessageFailed(String)
        case updateMessageFetchFailed(String)
        case updateMessageSaveFailed(String)
        case decodeMetadataFailed(String)
        case encodeMetadataFailed(String)
        case findProjectFailed(String)
        case findChatFailed(String)

        var errorDescription: String? {
            switch self {
            case .fetchChatsFailed(let details):
                return "Fetch chats failed: \(details)"
            case .createChatSaveFailed(let details):
                return "Create chat save failed: \(details)"
            case .fetchMessagesFailed(let details):
                return "Fetch messages failed: \(details)"
            case .saveMessageFailed(let details):
                return "Save message failed: \(details)"
            case .updateMessageFetchFailed(let details):
                return "Update message fetch failed: \(details)"
            case .updateMessageSaveFailed(let details):
                return "Update message save failed: \(details)"
            case .decodeMetadataFailed(let details):
                return "Decode metadata failed: \(details)"
            case .encodeMetadataFailed(let details):
                return "Encode metadata failed: \(details)"
            case .findProjectFailed(let details):
                return "Find project failed: \(details)"
            case .findChatFailed(let details):
                return "Find chat failed: \(details)"
            }
        }
    }

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

        let entities: [ChatThreadEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            log(.fetchChatsFailed(error.localizedDescription))
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

        do {
            try context.save()
        } catch {
            log(.createChatSaveFailed(error.localizedDescription))
        }

        return ref
    }

    func loadMessages(chatID: UUID) -> [ChatMessage] {
        let predicateChatID = chatID
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.chatID == predicateChatID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let entities: [ChatMessageEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            log(.fetchMessagesFailed(error.localizedDescription))
            return []
        }

        return entities.compactMap { entity in
            guard let role = ChatMessage.Role(rawValue: entity.roleRaw) else {
                return nil
            }

            let metadata = decodeMetadata(from: entity.metadataJSON)
            return ChatMessage(id: entity.id, role: role, text: entity.text, metadata: metadata, createdAt: entity.createdAt)
        }
    }

    func saveMessage(chatID: UUID, message: ChatMessage) {
        let entity = ChatMessageEntity(
            id: message.id,
            chatID: chatID,
            roleRaw: message.role.rawValue,
            text: message.text,
            metadataJSON: encodeMetadata(message.metadata),
            createdAt: message.createdAt,
            chat: findChatEntity(id: chatID)
        )
        context.insert(entity)

        do {
            try context.save()
        } catch {
            log(.saveMessageFailed(error.localizedDescription))
        }
    }

    func updateMessage(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) {
        let predicateMessageID = messageID
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.id == predicateMessageID }
        )

        let entity: ChatMessageEntity?
        do {
            entity = try context.fetch(descriptor).first
        } catch {
            log(.updateMessageFetchFailed(error.localizedDescription))
            return
        }

        guard let entity else {
            return
        }

        entity.chatID = chatID
        entity.text = text
        entity.metadataJSON = encodeMetadata(metadata)
        do {
            try context.save()
        } catch {
            log(.updateMessageSaveFailed(error.localizedDescription))
        }
    }

    private func findProjectEntity(id: UUID) -> ProjectEntity? {
        let predicateProjectID = id
        let descriptor = FetchDescriptor<ProjectEntity>(
            predicate: #Predicate { $0.id == predicateProjectID }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            log(.findProjectFailed(error.localizedDescription))
            return nil
        }
    }

    private func findChatEntity(id: UUID) -> ChatThreadEntity? {
        let predicateChatID = id
        let descriptor = FetchDescriptor<ChatThreadEntity>(
            predicate: #Predicate { $0.id == predicateChatID }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            log(.findChatFailed(error.localizedDescription))
            return nil
        }
    }

    private func log(_ error: RepositoryError) {
        NSLog("[CopilotForge][ChatRepo] %@", error.localizedDescription)
    }

    private func encodeMetadata(_ metadata: ChatMessage.Metadata?) -> String? {
        guard let metadata else { return nil }

        do {
            let data = try JSONEncoder().encode(metadata)
            return String(data: data, encoding: .utf8)
        } catch {
            log(.encodeMetadataFailed(error.localizedDescription))
            return nil
        }
    }

    private func decodeMetadata(from json: String?) -> ChatMessage.Metadata? {
        guard let json, let data = json.data(using: .utf8) else { return nil }

        do {
            return try JSONDecoder().decode(ChatMessage.Metadata.self, from: data)
        } catch {
            log(.decodeMetadataFailed(error.localizedDescription))
            return nil
        }
    }
}