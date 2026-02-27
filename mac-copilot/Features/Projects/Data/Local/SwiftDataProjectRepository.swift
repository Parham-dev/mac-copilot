import Foundation
import SwiftData

@MainActor
final class SwiftDataProjectRepository: ProjectRepository {
    private enum RepositoryError: LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case deleteFetchFailed(String)
        case deleteSaveFailed(String)

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let details):
                return "Project fetch failed: \(details)"
            case .saveFailed(let details):
                return "Project save failed: \(details)"
            case .deleteFetchFailed(let details):
                return "Project delete fetch failed: \(details)"
            case .deleteSaveFailed(let details):
                return "Project delete save failed: \(details)"
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProjects() throws -> [ProjectRef] {
        let descriptor = FetchDescriptor<ProjectEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let entities: [ProjectEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            let wrapped = RepositoryError.fetchFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        return entities.map {
            ProjectRef(id: $0.id, name: $0.name, localPath: $0.localPath)
        }
    }

    @discardableResult
    func createProject(name: String, localPath: String) throws -> ProjectRef {
        let ref = ProjectRef(name: name, localPath: localPath)
        let entity = ProjectEntity(id: ref.id, name: ref.name, localPath: ref.localPath)
        context.insert(entity)

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.saveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        return ref
    }

    func deleteProject(projectID: UUID) throws {
        let predicateProjectID = projectID
        let descriptor = FetchDescriptor<ProjectEntity>(
            predicate: #Predicate { $0.id == predicateProjectID }
        )

        let entity: ProjectEntity?
        do {
            entity = try context.fetch(descriptor).first
        } catch {
            let wrapped = RepositoryError.deleteFetchFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        guard let entity else {
            return
        }

        context.delete(entity)

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.deleteSaveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }
    }

    private func log(_ error: RepositoryError) {
        NSLog("[CopilotForge][ProjectRepo] %@", error.localizedDescription)
    }
}