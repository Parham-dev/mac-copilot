import Foundation

@MainActor
protocol AgentDefinitionRepository {
    func fetchDefinitions() -> [AgentDefinition]
    func definition(id: String) -> AgentDefinition?
}
