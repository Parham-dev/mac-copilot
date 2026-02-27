import Foundation
import SwiftData

@MainActor
final class SwiftDataStack: SwiftDataStoreProviding {

    let container: ModelContainer
    let context: ModelContext
    let startupError: String?

    init() {
        let schema = Schema([
            ProjectEntity.self,
            ChatThreadEntity.self,
            ChatMessageEntity.self,
            AgentRunEntity.self,
        ])

        let bootstrap = Self.makeContainer(schema: schema)
        container = bootstrap.container
        startupError = bootstrap.startupError

        context = ModelContext(container)
    }

    private static func makeContainer(schema: Schema) -> (container: ModelContainer, startupError: String?) {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return (try ModelContainer(for: schema, configurations: [configuration]), nil)
        } catch {
            let persistentMessage = "Persistent database initialization failed: \(error.localizedDescription)"
            NSLog("[CopilotForge][SwiftData] %@", persistentMessage)

            do {
                let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [inMemory])
                return (container, persistentMessage)
            } catch {
                let fallbackMessage = "In-memory database initialization also failed: \(error.localizedDescription)"
                NSLog("[CopilotForge][SwiftData] %@", fallbackMessage)
                let combined = "\(persistentMessage) | \(fallbackMessage)"
                preconditionFailure(combined)
            }
        }
    }
}