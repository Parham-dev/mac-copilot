import Foundation
import FactoryKit

extension Container {
    var agentExecutionService: Factory<any AgentExecutionServing> {
        self { @MainActor in
            PromptAgentExecutionService(promptRepository: self.promptRepository())
        }
        .singleton
    }

    var agentsEnvironment: Factory<AgentsEnvironment> {
        self { @MainActor in
            AgentsEnvironment(
                fetchDefinitionsUseCase: FetchAgentDefinitionsUseCase(repository: self.agentDefinitionRepository()),
                fetchRunsUseCase: FetchAgentRunsUseCase(repository: self.agentRunRepository()),
                createRunUseCase: CreateAgentRunUseCase(repository: self.agentRunRepository()),
                updateRunUseCase: UpdateAgentRunUseCase(repository: self.agentRunRepository()),
                executionService: self.agentExecutionService(),
                fetchModelCatalogUseCase: FetchModelCatalogUseCase(repository: self.modelRepository()),
                modelSelectionStore: self.modelSelectionStore()
            )
        }
        .singleton
    }
}
