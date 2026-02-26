import Foundation
import FactoryKit

extension Container {
    var projectRepository: Factory<any ProjectRepository> {
        self { @MainActor in SwiftDataProjectRepository(context: self.swiftDataStack().context) }
            .singleton
    }

    var chatRepository: Factory<any ChatRepository> {
        self { @MainActor in SwiftDataChatRepository(context: self.swiftDataStack().context) }
            .singleton
    }
}