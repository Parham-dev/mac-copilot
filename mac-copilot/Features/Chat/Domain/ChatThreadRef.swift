import Foundation

struct ChatThreadRef: Identifiable, Hashable, Codable {
    let id: UUID
    let projectID: UUID
    var title: String
    let createdAt: Date

    init(id: UUID = UUID(), projectID: UUID, title: String, createdAt: Date = .now) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.createdAt = createdAt
    }
}