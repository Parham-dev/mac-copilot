import Foundation

protocol ProfileRepository {
    func fetchProfile(accessToken: String) async throws -> ProfileSnapshot
}
