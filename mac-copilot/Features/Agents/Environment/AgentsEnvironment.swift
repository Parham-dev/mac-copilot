import Foundation
import Combine

@MainActor
final class AgentsEnvironment: ObservableObject {
    @Published private(set) var definitions: [AgentDefinition]
    @Published private(set) var runs: [AgentRun] = []

    private let fetchDefinitionsUseCase: FetchAgentDefinitionsUseCase
    private let fetchRunsUseCase: FetchAgentRunsUseCase
    private let createRunUseCase: CreateAgentRunUseCase
    private let updateRunUseCase: UpdateAgentRunUseCase

    init(
        fetchDefinitionsUseCase: FetchAgentDefinitionsUseCase,
        fetchRunsUseCase: FetchAgentRunsUseCase,
        createRunUseCase: CreateAgentRunUseCase,
        updateRunUseCase: UpdateAgentRunUseCase
    ) {
        self.fetchDefinitionsUseCase = fetchDefinitionsUseCase
        self.fetchRunsUseCase = fetchRunsUseCase
        self.createRunUseCase = createRunUseCase
        self.updateRunUseCase = updateRunUseCase
        self.definitions = fetchDefinitionsUseCase.execute()
    }

    func loadDefinitions() {
        definitions = fetchDefinitionsUseCase.execute()
    }

    func loadRuns(projectID: UUID? = nil, agentID: String? = nil) {
        do {
            runs = try fetchRunsUseCase.execute(projectID: projectID, agentID: agentID)
        } catch {
            NSLog("[CopilotForge][AgentsEnvironment] loadRuns failed: %@", error.localizedDescription)
        }
    }

    func definition(id: String) -> AgentDefinition? {
        definitions.first(where: { $0.id == id })
    }

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
}
