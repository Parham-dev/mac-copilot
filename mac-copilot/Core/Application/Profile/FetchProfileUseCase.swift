import Foundation

struct FetchProfileUseCase {
    private let repository: ProfileRepository

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func execute(accessToken: String) async throws -> ProfileSnapshot {
        try await repository.fetchProfile(accessToken: accessToken)
    }
}
