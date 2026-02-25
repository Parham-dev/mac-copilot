import Foundation
import SwiftData

@MainActor
final class SwiftDataProjectRepository: ProjectRepository {
    private enum RepositoryError: LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let details):
                return "Project fetch failed: \(details)"
            case .saveFailed(let details):
                return "Project save failed: \(details)"
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProjects() -> [ProjectRef] {
        let descriptor = FetchDescriptor<ProjectEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let entities: [ProjectEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            log(.fetchFailed(error.localizedDescription))
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

        do {
            try context.save()
        } catch {
            log(.saveFailed(error.localizedDescription))
        }

        return ref
    }

    private func log(_ error: RepositoryError) {
        NSLog("[CopilotForge][ProjectRepo] %@", error.localizedDescription)
    }
}