import Foundation
import Combine

@MainActor
final class GitHubAuthRepository: AuthRepository {
    private let service: GitHubAuthService
    private let subject: CurrentValueSubject<AuthSessionState, Never>
    private var cancellables = Set<AnyCancellable>()

    init(service: GitHubAuthService) {
        self.service = service
        self.subject = CurrentValueSubject(Self.mapState(from: service))

        service.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                self.publishState()
            }
            .store(in: &cancellables)
    }

    var state: AuthSessionState {
        Self.mapState(from: service)
    }

    var statePublisher: AnyPublisher<AuthSessionState, Never> {
        subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func restoreSessionIfNeeded() async {
        await service.restoreSessionIfNeeded()
        publishState()
    }

    func startDeviceFlow() async {
        await service.startDeviceFlow()
        publishState()
    }

    func pollForAuthorization() async {
        await service.pollForAuthorization()
        publishState()
    }

    func signOut() {
        service.signOut()
        publishState()
    }

    func currentAccessToken() -> String? {
        service.currentAccessToken()
    }

    private func publishState() {
        subject.send(Self.mapState(from: service))
    }

    private static func mapState(from service: GitHubAuthService) -> AuthSessionState {
        AuthSessionState(
            isAuthenticated: service.isAuthenticated,
            isLoading: service.isLoading,
            statusMessage: service.statusMessage,
            errorMessage: service.errorMessage,
            userCode: service.userCode,
            verificationURI: service.verificationURI
        )
    }
}
