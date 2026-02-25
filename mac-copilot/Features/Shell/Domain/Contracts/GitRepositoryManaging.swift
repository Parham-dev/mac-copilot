import Foundation

protocol GitRepositoryManaging {
    func isGitRepository(at path: String) async -> Bool
    func initializeRepository(at path: String) async throws
}
