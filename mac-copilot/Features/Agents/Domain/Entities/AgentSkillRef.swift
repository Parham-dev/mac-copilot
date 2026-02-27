import Foundation

struct AgentSkillRef: Hashable, Codable {
    var name: String
    var description: String
    var location: String
    var version: String?
}
