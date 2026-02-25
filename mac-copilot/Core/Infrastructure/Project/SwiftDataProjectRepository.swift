import Foundation
import SwiftData

@MainActor
final class SwiftDataProjectRepository: ProjectRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProjects() -> [ProjectRef] {
        let descriptor = FetchDescriptor<ProjectEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }

        return entities.map {
            ProjectRef(id: $0.id, name: $0.name, localPath: $0.localPath)
        }
    }

    @discardableResult
    func createProject(name: String, localPath: String) -> ProjectRef {
        let ref = ProjectRef(name: name, localPath: localPath)
        let entity = ProjectEntity(id: ref.id, name: ref.name, localPath: ref.localPath)
        context.insert(entity)
        try? context.save()
        return ref
    }
}