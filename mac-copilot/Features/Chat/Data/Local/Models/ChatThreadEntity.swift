import Foundation
import SwiftData

@Model
final class ChatThreadEntity {
    @Attribute(.unique) var id: UUID
    var projectID: UUID
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var project: ProjectEntity?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageEntity.chat)
    var messages: [ChatMessageEntity]

    init(id: UUID, projectID: UUID, title: String, createdAt: Date = .now, project: ProjectEntity?) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.createdAt = createdAt
        self.project = project
        self.messages = []
    }
}