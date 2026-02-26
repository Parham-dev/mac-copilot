import Foundation
import SwiftData

@MainActor
final class SwiftDataChatRepository: ChatRepository {
    private enum RepositoryError: LocalizedError {
        case fetchChatsFailed(String)
        case createChatSaveFailed(String)
        case deleteChatFetchFailed(String)
        case deleteChatSaveFailed(String)
        case updateChatTitleFetchFailed(String)
        case updateChatTitleSaveFailed(String)
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
            case .deleteChatFetchFailed(let details):
                return "Delete chat fetch failed: \(details)"
            case .deleteChatSaveFailed(let details):
                return "Delete chat save failed: \(details)"
            case .updateChatTitleFetchFailed(let details):
                return "Update chat title fetch failed: \(details)"
            case .updateChatTitleSaveFailed(let details):
                return "Update chat title save failed: \(details)"
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

    func fetchChats(projectID: UUID) throws -> [ChatThreadRef] {
        let predicateProjectID = projectID
        let descriptor = FetchDescriptor<ChatThreadEntity>(
            predicate: #Predicate { $0.projectID == predicateProjectID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let entities: [ChatThreadEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            let wrapped = RepositoryError.fetchChatsFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        return entities.map {
            ChatThreadRef(id: $0.id, projectID: $0.projectID, title: $0.title, createdAt: $0.createdAt)
        }
    }

    @discardableResult
    func createChat(projectID: UUID, title: String) throws -> ChatThreadRef {
        let ref = ChatThreadRef(projectID: projectID, title: title)
        let entity = ChatThreadEntity(id: ref.id, projectID: ref.projectID, title: ref.title, createdAt: ref.createdAt, project: findProjectEntity(id: projectID))
        context.insert(entity)

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.createChatSaveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        return ref
    }

    func deleteChat(chatID: UUID) throws {
        let predicateChatID = chatID
        let descriptor = FetchDescriptor<ChatThreadEntity>(
            predicate: #Predicate { $0.id == predicateChatID }
        )

        let entity: ChatThreadEntity?
        do {
            entity = try context.fetch(descriptor).first
        } catch {
            let wrapped = RepositoryError.deleteChatFetchFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        guard let entity else {
            return
        }

        context.delete(entity)

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.deleteChatSaveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }
    }

    func updateChatTitle(chatID: UUID, title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let predicateChatID = chatID
        let descriptor = FetchDescriptor<ChatThreadEntity>(
            predicate: #Predicate { $0.id == predicateChatID }
        )

        let entity: ChatThreadEntity?
        do {
            entity = try context.fetch(descriptor).first
        } catch {
            let wrapped = RepositoryError.updateChatTitleFetchFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        guard let entity else {
            return
        }

        entity.title = trimmed

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.updateChatTitleSaveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }
    }

    func loadMessages(chatID: UUID) throws -> [ChatMessage] {
        let predicateChatID = chatID
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.chatID == predicateChatID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let entities: [ChatMessageEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            let wrapped = RepositoryError.fetchMessagesFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        return entities.compactMap { entity in
            guard let role = ChatMessage.Role(rawValue: entity.roleRaw) else {
                return nil
            }

            let metadata = decodeMetadata(from: entity.metadataJSON)
            return ChatMessage(id: entity.id, role: role, text: entity.text, metadata: metadata, createdAt: entity.createdAt)
        }
    }

    func saveMessage(chatID: UUID, message: ChatMessage) throws {
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
            let wrapped = RepositoryError.saveMessageFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }
    }

    func updateMessage(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) throws {
        let predicateMessageID = messageID
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.id == predicateMessageID }
        )

        let entity: ChatMessageEntity?
        do {
            entity = try context.fetch(descriptor).first
        } catch {
            let wrapped = RepositoryError.updateMessageFetchFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
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
            let wrapped = RepositoryError.updateMessageSaveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }
    }

    private func findProjectEntity(id: UUID) -> ProjectEntity? {
        do {
            return try ChatEntityLookup.findProjectEntity(id: id, context: context)
        } catch {
            log(.findProjectFailed(error.localizedDescription))
            return nil
        }
    }

    private func findChatEntity(id: UUID) -> ChatThreadEntity? {
        do {
            return try ChatEntityLookup.findChatEntity(id: id, context: context)
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
            return try ChatMetadataCodec.encode(metadata)
        } catch {
            log(.encodeMetadataFailed(error.localizedDescription))
            return nil
        }
    }

    private func decodeMetadata(from json: String?) -> ChatMessage.Metadata? {
        guard let json else { return nil }

        do {
            return try ChatMetadataCodec.decode(from: json)
        } catch {
            log(.decodeMetadataFailed(error.localizedDescription))
            return nil
        }
    }
}