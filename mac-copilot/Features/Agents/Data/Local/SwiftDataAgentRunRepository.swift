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

        return entities
            .compactMap(mapToDomain)
            .filter { run in
                let projectMatches = projectID.map { run.projectID == $0 } ?? true
                let agentMatches = agentID.map { run.agentID == $0 } ?? true
                return projectMatches && agentMatches
            }
    }

    func fetchRun(id: UUID) throws -> AgentRun? {
        let predicateID = id
        let descriptor = FetchDescriptor<AgentRunEntity>(
            predicate: #Predicate { $0.id == predicateID }
        )

        do {
            return try context.fetch(descriptor).first.flatMap(mapToDomain)
        } catch {
            let wrapped = RepositoryError.fetchRunFailed(error.localizedDescription)
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
            inputPayloadJSON: encodeInputPayload(run.inputPayload),
            statusRaw: run.status.rawValue,
            streamedOutput: run.streamedOutput,
            finalOutput: run.finalOutput,
            startedAt: run.startedAt,
            completedAt: run.completedAt,
            diagnosticsJSON: encodeDiagnostics(run.diagnostics)
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
        entity.inputPayloadJSON = encodeInputPayload(run.inputPayload)
        entity.statusRaw = run.status.rawValue
        entity.streamedOutput = run.streamedOutput
        entity.finalOutput = run.finalOutput
        entity.startedAt = run.startedAt
        entity.completedAt = run.completedAt
        entity.diagnosticsJSON = encodeDiagnostics(run.diagnostics)

        do {
            try context.save()
        } catch {
            let wrapped = RepositoryError.updateSaveFailed(error.localizedDescription)
            log(wrapped)
            throw wrapped
        }
    }

    private func mapToDomain(_ entity: AgentRunEntity) -> AgentRun? {
        guard let status = AgentRunStatus(rawValue: entity.statusRaw) else {
            return nil
        }

        return AgentRun(
            id: entity.id,
            agentID: entity.agentID,
            projectID: entity.projectID,
            inputPayload: decodeInputPayload(entity.inputPayloadJSON),
            status: status,
            streamedOutput: entity.streamedOutput,
            finalOutput: entity.finalOutput,
            startedAt: entity.startedAt,
            completedAt: entity.completedAt,
            diagnostics: decodeDiagnostics(entity.diagnosticsJSON)
        )
    }

    private func encodeInputPayload(_ payload: [String: String]) -> String {
        do {
            let data = try JSONEncoder().encode(payload)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            log(.encodeInputPayloadFailed(error.localizedDescription))
            return "{}"
        }
    }

    private func decodeInputPayload(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8) else { return [:] }

        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            log(.decodeInputPayloadFailed(error.localizedDescription))
            return [:]
        }
    }

    private func encodeDiagnostics(_ diagnostics: AgentRunDiagnostics) -> String {
        do {
            let data = try JSONEncoder().encode(diagnostics)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            log(.encodeDiagnosticsFailed(error.localizedDescription))
            return "{}"
        }
    }

    private func decodeDiagnostics(_ json: String) -> AgentRunDiagnostics {
        guard let data = json.data(using: .utf8) else { return .init() }

        do {
            return try JSONDecoder().decode(AgentRunDiagnostics.self, from: data)
        } catch {
            log(.decodeDiagnosticsFailed(error.localizedDescription))
            return .init()
        }
    }

    private func log(_ error: RepositoryError) {
        NSLog("[CopilotForge][AgentRunRepo] %@", error.localizedDescription)
    }
}
