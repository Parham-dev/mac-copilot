import Foundation
import FactoryKit

extension Container {
    var agentsEnvironment: Factory<AgentsEnvironment> {
        self { @MainActor in
            AgentsEnvironment(
                fetchDefinitionsUseCase: FetchAgentDefinitionsUseCase(repository: self.agentDefinitionRepository()),
                fetchRunsUseCase: FetchAgentRunsUseCase(repository: self.agentRunRepository()),
                createRunUseCase: CreateAgentRunUseCase(repository: self.agentRunRepository()),
                updateRunUseCase: UpdateAgentRunUseCase(repository: self.agentRunRepository())
            )
        }
        .singleton
    }
}
