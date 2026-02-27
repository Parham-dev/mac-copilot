import Foundation

@MainActor
struct FetchAgentDefinitionsUseCase {
    private let repository: AgentDefinitionRepository

    init(repository: AgentDefinitionRepository) {
        self.repository = repository
    }

    func execute() -> [AgentDefinition] {
        repository.fetchDefinitions()
    }
}

@MainActor
struct FetchAgentRunsUseCase {
    private let repository: AgentRunRepository

    init(repository: AgentRunRepository) {
        self.repository = repository
    }

    func execute(projectID: UUID? = nil, agentID: String? = nil) throws -> [AgentRun] {
        try repository.fetchRuns(projectID: projectID, agentID: agentID)
    }
}

@MainActor
struct CreateAgentRunUseCase {
    private let repository: AgentRunRepository

    init(repository: AgentRunRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(run: AgentRun) throws -> AgentRun {
        try repository.createRun(run)
    }
}

@MainActor
struct UpdateAgentRunUseCase {
    private let repository: AgentRunRepository

    init(repository: AgentRunRepository) {
        self.repository = repository
    }

    func execute(run: AgentRun) throws {
        try repository.updateRun(run)
    }
}
