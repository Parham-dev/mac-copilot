import Foundation
import SwiftData

@MainActor
final class SwiftDataAgentRunRepository: AgentRunRepository {
    private enum RepositoryError: LocalizedError {
        case fetchRunsFailed(String)
        case fetchRunFailed(String)
        case saveFailed(String)
        case updateFetchFailed(String)
        case updateSaveFailed(String)
        case deleteFetchFailed(String)
        case deleteSaveFailed(String)
        case invalidStatus(String)
        case encodeInputPayloadFailed(String)
        case decodeInputPayloadFailed(String)
        case encodeDiagnosticsFailed(String)
        case decodeDiagnosticsFailed(String)

        var errorDescription: String? {
            switch self {
            case .fetchRunsFailed(let details):
                return "Fetch agent runs failed: \(details)"
            case .fetchRunFailed(let details):
                return "Fetch agent run failed: \(details)"
            case .saveFailed(let details):
                return "Save agent run failed: \(details)"
            case .updateFetchFailed(let details):
                return "Update agent run fetch failed: \(details)"
            case .updateSaveFailed(let details):
                return "Update agent run save failed: \(details)"
            case .deleteFetchFailed(let details):
                return "Delete agent run fetch failed: \(details)"
            case .deleteSaveFailed(let details):
                return "Delete agent run save failed: \(details)"
            case .invalidStatus(let value):
                return "Decode agent run status failed: invalid raw value '\(value)'"
            case .encodeInputPayloadFailed(let details):
                return "Encode agent run input payload failed: \(details)"
            case .decodeInputPayloadFailed(let details):
                return "Decode agent run input payload failed: \(details)"
            case .encodeDiagnosticsFailed(let details):
                return "Encode agent run diagnostics failed: \(details)"
            case .decodeDiagnosticsFailed(let details):
                return "Decode agent run diagnostics failed: \(details)"
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchRuns(projectID: UUID?, agentID: String?) throws -> [AgentRun] {
        let descriptor = FetchDescriptor<AgentRunEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        let entities: [AgentRunEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            let wrapped = RepositoryError.fetchRunsFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        do {
            return try entities
                .map(mapToDomain)
                .filter { run in
                    let projectMatches = projectID.map { run.projectID == $0 } ?? true
                    let agentMatches = agentID.map { run.agentID == $0 } ?? true
                    return projectMatches && agentMatches
                }
        } catch {
            let wrapped: RepositoryError
            if let repositoryError = error as? RepositoryError {
                wrapped = repositoryError
            } else {
                wrapped = RepositoryError.fetchRunsFailed(error.localizedDescription)
            }
            log(wrapped)
            throw wrapped
        }
    }

    func fetchRun(id: UUID) throws -> AgentRun? {
        let predicateID = id
        let descriptor = FetchDescriptor<AgentRunEntity>(
            predicate: #Predicate { $0.id == predicateID }
        )

        do {
            guard let entity = try context.fetch(descriptor).first else {
                return nil
            }
            return try mapToDomain(entity)
        } catch {
            let wrapped: RepositoryError
            if let repositoryError = error as? RepositoryError {
                wrapped = repositoryError
            } else {
                wrapped = RepositoryError.fetchRunFailed(error.localizedDescription)
            }
            log(wrapped)
            throw wrapped
        }
    }

    @discardableResult
    func createRun(_ run: AgentRun) throws -> AgentRun {
        let entity = AgentRunEntity(
            id: run.id,
            agentID: run.agentID,
            projectID: run.projectID,
            inputPayloadJSON: try encodeInputPayload(run.inputPayload),
            statusRaw: run.status.rawValue,
            streamedOutput: run.streamedOutput,
            finalOutput: run.finalOutput,
            startedAt: run.startedAt,
            completedAt: run.completedAt,
            diagnosticsJSON: try encodeDiagnostics(run.diagnostics)
        )

        context.insert(entity)

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.saveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        return run
    }

    func updateRun(_ run: AgentRun) throws {
        let predicateID = run.id
        let descriptor = FetchDescriptor<AgentRunEntity>(
            predicate: #Predicate { $0.id == predicateID }
        )

        let entity: AgentRunEntity?
        do {
            entity = try context.fetch(descriptor).first
        } catch {
            let wrapped = RepositoryError.updateFetchFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }

        guard let entity else { return }

        entity.agentID = run.agentID
        entity.projectID = run.projectID
        entity.inputPayloadJSON = try encodeInputPayload(run.inputPayload)
        entity.statusRaw = run.status.rawValue
        entity.streamedOutput = run.streamedOutput
        entity.finalOutput = run.finalOutput
        entity.startedAt = run.startedAt
        entity.completedAt = run.completedAt
        entity.diagnosticsJSON = try encodeDiagnostics(run.diagnostics)

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.updateSaveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }
    }

    func deleteRun(id: UUID) throws {
        let predicateID = id
        let descriptor = FetchDescriptor<AgentRunEntity>(
            predicate: #Predicate { $0.id == predicateID }
        )

        let entity: AgentRunEntity?
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

    private func mapToDomain(_ entity: AgentRunEntity) throws -> AgentRun {
        guard let status = AgentRunStatus(rawValue: entity.statusRaw) else {
            throw RepositoryError.invalidStatus(entity.statusRaw)
        }

        return AgentRun(
            id: entity.id,
            agentID: entity.agentID,
            projectID: entity.projectID,
            inputPayload: try decodeInputPayload(entity.inputPayloadJSON),
            status: status,
            streamedOutput: entity.streamedOutput,
            finalOutput: entity.finalOutput,
            startedAt: entity.startedAt,
            completedAt: entity.completedAt,
            diagnostics: try decodeDiagnostics(entity.diagnosticsJSON)
        )
    }

    private func encodeInputPayload(_ payload: [String: String]) throws -> String {
        do {
            let data = try JSONEncoder().encode(payload)
            guard let encoded = String(data: data, encoding: .utf8) else {
                throw RepositoryError.encodeInputPayloadFailed("UTF-8 conversion failed")
            }
            return encoded
        } catch {
            if let repositoryError = error as? RepositoryError {
                throw repositoryError
            }
            throw RepositoryError.encodeInputPayloadFailed(error.localizedDescription)
        }
    }

    private func decodeInputPayload(_ json: String) throws -> [String: String] {
        guard let data = json.data(using: .utf8) else {
            throw RepositoryError.decodeInputPayloadFailed("Invalid UTF-8 payload")
        }

        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            throw RepositoryError.decodeInputPayloadFailed(error.localizedDescription)
        }
    }

    private func encodeDiagnostics(_ diagnostics: AgentRunDiagnostics) throws -> String {
        do {
            let data = try JSONEncoder().encode(diagnostics)
            guard let encoded = String(data: data, encoding: .utf8) else {
                throw RepositoryError.encodeDiagnosticsFailed("UTF-8 conversion failed")
            }
            return encoded
        } catch {
            if let repositoryError = error as? RepositoryError {
                throw repositoryError
            }
            throw RepositoryError.encodeDiagnosticsFailed(error.localizedDescription)
        }
    }

    private func decodeDiagnostics(_ json: String) throws -> AgentRunDiagnostics {
        guard let data = json.data(using: .utf8) else {
            throw RepositoryError.decodeDiagnosticsFailed("Invalid UTF-8 payload")
        }

        do {
            return try JSONDecoder().decode(AgentRunDiagnostics.self, from: data)
        } catch {
            throw RepositoryError.decodeDiagnosticsFailed(error.localizedDescription)
        }
    }

    private func log(_ error: RepositoryError) {
        NSLog("[CopilotForge][AgentRunRepo] %@", error.localizedDescription)
    }
}
