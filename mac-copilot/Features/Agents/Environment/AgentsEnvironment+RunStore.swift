import Foundation

extension AgentsEnvironment {
    @discardableResult
    func createRun(agentID: String, projectID: UUID?, inputPayload: [String: String]) throws -> AgentRun {
        let run = AgentRun(
            agentID: agentID,
            projectID: projectID,
            inputPayload: inputPayload,
            status: .queued,
            startedAt: .now
        )

        let created = try createRunUseCase.execute(run: run)
        runs.insert(created, at: 0)
        return created
    }

    func updateRun(_ run: AgentRun) throws {
        try updateRunUseCase.execute(run: run)

        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
        }
    }

    func deleteRun(id: UUID, projectID: UUID? = nil, agentID: String? = nil) throws {
        try deleteRunUseCase.execute(runID: id)
        runs.removeAll { $0.id == id }
        loadRuns(projectID: projectID, agentID: agentID)
    }
}
