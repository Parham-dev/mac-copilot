import Foundation

struct AgentRun: Identifiable, Hashable, Codable {
    let id: UUID
    var agentID: String
    var projectID: UUID?
    var inputPayload: [String: String]
    var status: AgentRunStatus
    var streamedOutput: String?
    var finalOutput: String?
    var startedAt: Date
    var completedAt: Date?
    var diagnostics: AgentRunDiagnostics

    init(
        id: UUID = UUID(),
        agentID: String,
        projectID: UUID? = nil,
        inputPayload: [String: String],
        status: AgentRunStatus = .queued,
        streamedOutput: String? = nil,
        finalOutput: String? = nil,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        diagnostics: AgentRunDiagnostics = .init()
    ) {
        self.id = id
        self.agentID = agentID
        self.projectID = projectID
        self.inputPayload = inputPayload
        self.status = status
        self.streamedOutput = streamedOutput
        self.finalOutput = finalOutput
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.diagnostics = diagnostics
    }
}

enum AgentRunStatus: String, Hashable, Codable, CaseIterable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

struct AgentRunDiagnostics: Hashable, Codable {
    var toolTraces: [String]
    var warnings: [String]

    init(toolTraces: [String] = [], warnings: [String] = []) {
        self.toolTraces = toolTraces
        self.warnings = warnings
    }
}
