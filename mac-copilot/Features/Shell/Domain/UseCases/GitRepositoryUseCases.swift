import Foundation

struct CheckGitRepositoryUseCase {
    private let repositoryManager: GitRepositoryManaging

    init(repositoryManager: GitRepositoryManaging) {
        self.repositoryManager = repositoryManager
    }

    func execute(path: String) async -> Bool {
        await repositoryManager.isGitRepository(at: path)
    }
}

struct FetchGitRepositoryStatusUseCase {
    private let repositoryManager: GitRepositoryManaging

    init(repositoryManager: GitRepositoryManaging) {
        self.repositoryManager = repositoryManager
    }

    func execute(path: String) async throws -> GitRepositoryStatus {
        try await repositoryManager.repositoryStatus(at: path)
    }
}

struct FetchGitFileChangesUseCase {
    private let repositoryManager: GitRepositoryManaging

    init(repositoryManager: GitRepositoryManaging) {
        self.repositoryManager = repositoryManager
    }

    func execute(path: String) async throws -> [GitFileChange] {
        try await repositoryManager.fileChanges(at: path)
    }
}

struct FetchGitRecentCommitsUseCase {
    private let repositoryManager: GitRepositoryManaging

    init(repositoryManager: GitRepositoryManaging) {
        self.repositoryManager = repositoryManager
    }

    func execute(path: String, limit: Int = 5) async throws -> [GitRecentCommit] {
        try await repositoryManager.recentCommits(at: path, limit: limit)
    }
}

struct InitializeGitRepositoryUseCase {
    private let repositoryManager: GitRepositoryManaging

    init(repositoryManager: GitRepositoryManaging) {
        self.repositoryManager = repositoryManager
    }

    func execute(path: String) async throws {
        try await repositoryManager.initializeRepository(at: path)
    }
}

struct CommitGitChangesUseCase {
    private let repositoryManager: GitRepositoryManaging

    init(repositoryManager: GitRepositoryManaging) {
        self.repositoryManager = repositoryManager
    }

    func execute(path: String, message: String) async throws {
        try await repositoryManager.commit(at: path, message: message)
    }
}
