import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var copilotReport: CopilotReport?
    @Published private(set) var rawUserJSON = ""
    @Published private(set) var checks: [EndpointCheck] = []

    private let fetchProfileUseCase: FetchProfileUseCase

    init(fetchProfileUseCase: FetchProfileUseCase) {
        self.fetchProfileUseCase = fetchProfileUseCase
    }

    func refresh(accessToken: String) async {
        isLoading = true
        errorMessage = nil
        checks = []
        copilotReport = nil

        do {
            let snapshot = try await fetchProfileUseCase.execute(accessToken: accessToken)
            userProfile = snapshot.userProfile
            copilotReport = snapshot.copilotReport
            rawUserJSON = snapshot.rawUserJSON
            checks = snapshot.checks
        } catch {
            errorMessage = UserFacingErrorMapper.message(error, fallback: "Could not load profile data right now.")
        }

        isLoading = false
    }

    func setMissingTokenError() {
        errorMessage = "No GitHub token found. Sign in again."
    }
}
