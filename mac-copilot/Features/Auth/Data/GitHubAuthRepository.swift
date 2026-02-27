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

        // Use receive(on:) to observe *after* the @Published values have been
        // written, so mapState always sees the current (post-mutation) state.
        // objectWillChange fires *before* mutations are applied, which would
        // capture stale values.
        service.objectWillChange
            .receive(on: RunLoop.main)
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
    }

    func startDeviceFlow() async {
        await service.startDeviceFlow()
    }

    func pollForAuthorization() async {
        await service.pollForAuthorization()
    }

    func signOut() {
        service.signOut()
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
