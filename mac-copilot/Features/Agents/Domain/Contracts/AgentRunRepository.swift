import Foundation

@MainActor
protocol AgentRunRepository {
    func fetchRuns(projectID: UUID?, agentID: String?) throws -> [AgentRun]
    func fetchRun(id: UUID) throws -> AgentRun?

    @discardableResult
    func createRun(_ run: AgentRun) throws -> AgentRun

    func updateRun(_ run: AgentRun) throws
}
