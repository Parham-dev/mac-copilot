import Foundation

struct ProjectRef: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var localPath: String

    init(id: UUID = UUID(), name: String, localPath: String) {
        self.id = id
        self.name = name
        self.localPath = localPath
    }
}
