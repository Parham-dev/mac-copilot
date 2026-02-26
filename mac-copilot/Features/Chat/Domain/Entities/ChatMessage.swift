import Foundation

struct ChatMessage: Identifiable, Hashable {
    struct Metadata: Codable, Hashable {
        enum TranscriptSegment: Codable, Hashable {
            case text(String)
            case tool(ToolExecution)
        }

        var statusChips: [String]
        var toolExecutions: [ToolExecution]
        var transcriptSegments: [TranscriptSegment]

        init(
            statusChips: [String] = [],
            toolExecutions: [ToolExecution] = [],
            transcriptSegments: [TranscriptSegment] = []
        ) {
            self.statusChips = statusChips
            self.toolExecutions = toolExecutions
            self.transcriptSegments = transcriptSegments
        }
    }

    struct ToolExecution: Identifiable, Codable, Hashable {
        let id: UUID
        let toolName: String
        let success: Bool
        let details: String?
        let input: String?
        let output: String?

        init(id: UUID = UUID(), toolName: String, success: Bool, details: String?, input: String? = nil, output: String? = nil) {
            self.id = id
            self.toolName = toolName
            self.success = success
            self.details = details
            self.input = input
            self.output = output
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
