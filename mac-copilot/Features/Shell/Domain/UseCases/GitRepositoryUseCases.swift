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

struct InitializeGitRepositoryUseCase {
    private let repositoryManager: GitRepositoryManaging

    init(repositoryManager: GitRepositoryManaging) {
        self.repositoryManager = repositoryManager
    }

    func execute(path: String) async throws {
        try await repositoryManager.initializeRepository(at: path)
    }
}
