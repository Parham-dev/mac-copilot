import Foundation
import SwiftData

@Model
final class ProjectEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var localPath: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatThreadEntity.project)
    var chats: [ChatThreadEntity]

    init(id: UUID, name: String, localPath: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.localPath = localPath
        self.createdAt = createdAt
        self.chats = []
    }
}