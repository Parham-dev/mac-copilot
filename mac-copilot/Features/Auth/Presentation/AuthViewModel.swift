import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthSessionState

    private let repository: any AuthRepository
    private let restoreSessionUseCase: RestoreAuthSessionUseCase
    private let startDeviceFlowUseCase: StartGitHubDeviceFlowUseCase
    private let pollAuthorizationUseCase: PollGitHubAuthorizationUseCase
    private let signOutUseCase: SignOutUseCase
    private var cancellables = Set<AnyCancellable>()

    init(repository: any AuthRepository) {
        self.repository = repository
        self.state = repository.state
        self.restoreSessionUseCase = RestoreAuthSessionUseCase(repository: repository)
        self.startDeviceFlowUseCase = StartGitHubDeviceFlowUseCase(repository: repository)
        self.pollAuthorizationUseCase = PollGitHubAuthorizationUseCase(repository: repository)
        self.signOutUseCase = SignOutUseCase(repository: repository)

        repository.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &cancellables)
    }

    var isAuthenticated: Bool { state.isAuthenticated }
    var isLoading: Bool { state.isLoading }
    var statusMessage: String { state.statusMessage }
    var errorMessage: String? { state.errorMessage }
    var userCode: String? { state.userCode }
    var verificationURI: String? { state.verificationURI }

    func restoreSessionIfNeeded() async {
        await restoreSessionUseCase.execute()
    }

    func startDeviceFlow() async {
        await startDeviceFlowUseCase.execute()
    }

    func pollForAuthorization() async {
        await pollAuthorizationUseCase.execute()
    }

    func signOut() {
        signOutUseCase.execute()
    }

    func currentAccessToken() -> String? {
        repository.currentAccessToken()
    }
}
