import Foundation

enum GitFileChangeState: String, CaseIterable, Sendable {
    case added = "A"
    case modified = "M"
    case deleted = "D"

    var title: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        }
    }
}

struct GitFileChange: Identifiable, Sendable {
    let path: String
    let state: GitFileChangeState
    let addedLines: Int
    let deletedLines: Int
    let isStaged: Bool
    let isUnstaged: Bool

    var id: String {
        path
    }
}

struct GitRepositoryStatus: Sendable {
    let branchName: String
    let changedFilesCount: Int
    let repositoryPath: String

    var isClean: Bool {
        changedFilesCount == 0
    }

    var statusText: String {
        if isClean {
            return "Clean"
        }
        return "\(changedFilesCount) files changed"
    }
}

struct GitRecentCommit: Identifiable, Sendable {
    let shortHash: String
    let author: String
    let relativeTime: String
    let message: String

    var id: String {
        shortHash + message
    }
}

protocol GitRepositoryManaging {
    func isGitRepository(at path: String) async -> Bool
    func repositoryStatus(at path: String) async throws -> GitRepositoryStatus
    func fileChanges(at path: String) async throws -> [GitFileChange]
    func recentCommits(at path: String, limit: Int) async throws -> [GitRecentCommit]
    func initializeRepository(at path: String) async throws
    func commit(at path: String, message: String) async throws
}
