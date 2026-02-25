import Foundation

struct ChatMessage: Identifiable, Hashable {
    struct Metadata: Codable, Hashable {
        var statusChips: [String]
        var toolExecutions: [ToolExecution]

        init(statusChips: [String] = [], toolExecutions: [ToolExecution] = []) {
            self.statusChips = statusChips
            self.toolExecutions = toolExecutions
        }
    }

    struct ToolExecution: Identifiable, Codable, Hashable {
        let id: UUID
        let toolName: String
        let success: Bool
        let details: String?

        init(id: UUID = UUID(), toolName: String, success: Bool, details: String?) {
            self.id = id
            self.toolName = toolName
            self.success = success
            self.details = details
        }
    }

    enum Role: String {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String
    var metadata: Metadata?
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, metadata: Metadata? = nil, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.metadata = metadata
        self.createdAt = createdAt
    }
}
