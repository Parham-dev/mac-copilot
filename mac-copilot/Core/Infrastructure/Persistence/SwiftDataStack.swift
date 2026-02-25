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

        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            NSLog("[CopilotForge][SwiftData] Falling back to in-memory container: %@", error.localizedDescription)
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }

        context = ModelContext(container)
    }
}