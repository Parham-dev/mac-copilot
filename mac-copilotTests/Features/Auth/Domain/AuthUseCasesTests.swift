import Foundation
import Combine
import Testing
@testable import mac_copilot

/// Tests that each use case delegates exactly one call to the correct
/// repository method and nothing else.
@MainActor
struct AuthUseCasesTests {

    // MARK: - RestoreAuthSessionUseCase

    @Test(.tags(.unit, .async_)) func restoreSession_delegatesToRepository() async {
        let repo = SpyAuthRepository()
        let useCase = RestoreAuthSessionUseCase(repository: repo)

        await useCase.execute()

        #expect(repo.restoreCalls == 1)
        #expect(repo.startDeviceFlowCalls == 0)
        #expect(repo.pollCalls == 0)
        #expect(repo.signOutCalls == 0)
    }

    // MARK: - StartGitHubDeviceFlowUseCase

    @Test(.tags(.unit, .async_)) func startDeviceFlow_delegatesToRepository() async {
        let repo = SpyAuthRepository()
        let useCase = StartGitHubDeviceFlowUseCase(repository: repo)

        await useCase.execute()

        #expect(repo.startDeviceFlowCalls == 1)
        #expect(repo.restoreCalls == 0)
        #expect(repo.pollCalls == 0)
        #expect(repo.signOutCalls == 0)
    }

    // MARK: - PollGitHubAuthorizationUseCase

    @Test(.tags(.unit, .async_)) func pollAuthorization_delegatesToRepository() async {
        let repo = SpyAuthRepository()
        let useCase = PollGitHubAuthorizationUseCase(repository: repo)

        await useCase.execute()

        #expect(repo.pollCalls == 1)
        #expect(repo.restoreCalls == 0)
        #expect(repo.startDeviceFlowCalls == 0)
        #expect(repo.signOutCalls == 0)
    }

    // MARK: - SignOutUseCase

    @Test(.tags(.unit)) func signOut_delegatesToRepository() {
        let repo = SpyAuthRepository()
        let useCase = SignOutUseCase(repository: repo)

        useCase.execute()

        #expect(repo.signOutCalls == 1)
        #expect(repo.restoreCalls == 0)
        #expect(repo.startDeviceFlowCalls == 0)
        #expect(repo.pollCalls == 0)
    }

    // MARK: - Use cases are independent (no shared state bleed)

    @Test(.tags(.unit, .async_)) func multipleUseCasesShareRepositoryButDoNotBleed() async {
        let repo = SpyAuthRepository()
        let restore = RestoreAuthSessionUseCase(repository: repo)
        let start = StartGitHubDeviceFlowUseCase(repository: repo)
        let signOut = SignOutUseCase(repository: repo)

        await restore.execute()
        await start.execute()
        signOut.execute()

        #expect(repo.restoreCalls == 1)
        #expect(repo.startDeviceFlowCalls == 1)
        #expect(repo.signOutCalls == 1)
        #expect(repo.pollCalls == 0)
    }
}

// MARK: - Test double

@MainActor
private final class SpyAuthRepository: AuthRepository {
    private(set) var restoreCalls = 0
    private(set) var startDeviceFlowCalls = 0
    private(set) var pollCalls = 0
    private(set) var signOutCalls = 0

    private let subject = CurrentValueSubject<AuthSessionState, Never>(.initial)

    var state: AuthSessionState { subject.value }

    var statePublisher: AnyPublisher<AuthSessionState, Never> {
        subject.eraseToAnyPublisher()
    }

    func restoreSessionIfNeeded() async {
        restoreCalls += 1
    }

    func startDeviceFlow() async {
        startDeviceFlowCalls += 1
    }

    func pollForAuthorization() async {
        pollCalls += 1
    }

    func signOut() {
        signOutCalls += 1
    }

    func currentAccessToken() -> String? {
        nil
    }
}
