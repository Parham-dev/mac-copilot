import Foundation
import SwiftData

@Model
final class AgentRunEntity {
    @Attribute(.unique) var id: UUID
    var agentID: String
    var projectID: UUID?
    var inputPayloadJSON: String
    var statusRaw: String
    var streamedOutput: String?
    var finalOutput: String?
    var startedAt: Date
    var completedAt: Date?
    var diagnosticsJSON: String

    init(
        id: UUID,
        agentID: String,
        projectID: UUID?,
        inputPayloadJSON: String,
        statusRaw: String,
        streamedOutput: String? = nil,
        finalOutput: String? = nil,
        startedAt: Date,
        completedAt: Date? = nil,
        diagnosticsJSON: String
    ) {
        self.id = id
        self.agentID = agentID
        self.projectID = projectID
        self.inputPayloadJSON = inputPayloadJSON
        self.statusRaw = statusRaw
        self.streamedOutput = streamedOutput
        self.finalOutput = finalOutput
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.diagnosticsJSON = diagnosticsJSON
    }
}
