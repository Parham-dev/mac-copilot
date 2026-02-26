import Foundation
import SwiftData

enum ChatEntityLookup {
    static func findProjectEntity(id: UUID, context: ModelContext) throws -> ProjectEntity? {
        let predicateProjectID = id
        let descriptor = FetchDescriptor<ProjectEntity>(
            predicate: #Predicate { $0.id == predicateProjectID }
        )

        return try context.fetch(descriptor).first
    }

    static func findChatEntity(id: UUID, context: ModelContext) throws -> ChatThreadEntity? {
        let predicateChatID = id
        let descriptor = FetchDescriptor<ChatThreadEntity>(
            predicate: #Predicate { $0.id == predicateChatID }
        )

        return try context.fetch(descriptor).first
    }
}