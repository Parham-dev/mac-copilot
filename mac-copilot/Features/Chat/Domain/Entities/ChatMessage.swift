import Foundation

struct ChatMessage: Identifiable, Hashable {
    struct Metadata: Codable, Hashable {
        private enum CodingKeys: String, CodingKey {
            case statusChips
            case toolExecutions
            case transcriptSegments
        }

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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            statusChips = try container.decodeIfPresent([String].self, forKey: .statusChips) ?? []
            toolExecutions = try container.decodeIfPresent([ToolExecution].self, forKey: .toolExecutions) ?? []
            transcriptSegments = try container.decodeIfPresent([TranscriptSegment].self, forKey: .transcriptSegments) ?? []
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(statusChips, forKey: .statusChips)
            try container.encode(toolExecutions, forKey: .toolExecutions)
            try container.encode(transcriptSegments, forKey: .transcriptSegments)
        }
    }

    struct ToolExecution: Identifiable, Codable, Hashable {
        private enum CodingKeys: String, CodingKey {
            case id
            case toolName
            case success
            case details
            case input
            case output
        }

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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            toolName = try container.decode(String.self, forKey: .toolName)
            success = try container.decode(Bool.self, forKey: .success)
            details = try container.decodeIfPresent(String.self, forKey: .details)
            input = try container.decodeIfPresent(String.self, forKey: .input)
            output = try container.decodeIfPresent(String.self, forKey: .output)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(toolName, forKey: .toolName)
            try container.encode(success, forKey: .success)
            try container.encodeIfPresent(details, forKey: .details)
            try container.encodeIfPresent(input, forKey: .input)
            try container.encodeIfPresent(output, forKey: .output)
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
