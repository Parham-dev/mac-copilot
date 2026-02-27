import Foundation
import FactoryKit

extension Container {
    var agentDefinitionRepository: Factory<any AgentDefinitionRepository> {
        self { @MainActor in BuiltInAgentDefinitionRepository() }
            .singleton
    }

    var agentRunRepository: Factory<any AgentRunRepository> {
        self { @MainActor in SwiftDataAgentRunRepository(context: self.swiftDataStack().context) }
            .singleton
    }

    var projectRepository: Factory<any ProjectRepository> {
        self { @MainActor in SwiftDataProjectRepository(context: self.swiftDataStack().context) }
            .singleton
    }

    var chatRepository: Factory<any ChatRepository> {
        self { @MainActor in SwiftDataChatRepository(context: self.swiftDataStack().context) }
            .singleton
    }
}