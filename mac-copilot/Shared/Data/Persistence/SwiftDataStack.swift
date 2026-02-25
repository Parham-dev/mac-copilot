import Foundation
import SwiftData

@MainActor
final class SwiftDataStack {
    static let shared = SwiftDataStack()

    let container: ModelContainer
    let context: ModelContext

    private init() {
        let schema = Schema([
            ProjectEntity.self,
            ChatThreadEntity.self,
            ChatMessageEntity.self,
        ])

        container = Self.makeContainer(schema: schema)

        context = ModelContext(container)
    }

    private static func makeContainer(schema: Schema) -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            NSLog("[CopilotForge][SwiftData] Falling back to in-memory container: %@", error.localizedDescription)

            do {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                let message = "SwiftData initialization failed for both persistent and in-memory modes: \(error.localizedDescription)"
                NSLog("[CopilotForge][SwiftData] %@", message)
                fatalError(message)
            }
        }
    }
}