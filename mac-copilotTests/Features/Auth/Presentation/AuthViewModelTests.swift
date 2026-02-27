import Foundation
import Combine
import Testing
@testable import mac_copilot

/// Unit tests for AuthViewModel.
///
/// AuthViewModel is a thin projection layer: it subscribes to AuthRepository's
/// publisher and forwards actions to the four use cases.  Tests use a
/// ControlledAuthRepository — a test double that lets us:
///   • seed the initial AuthSessionState
///   • push new states through the Combine publisher
///   • count how many times each repository method was called
@MainActor
struct AuthViewModelTests {

    // MARK: - Initial state projection

    @Test(.tags(.unit)) func init_projectsRepositoryInitialState() {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        #expect(viewModel.state == .initial)
        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.statusMessage == "Sign in required")
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.userCode == nil)
        #expect(viewModel.verificationURI == nil)
    }

    @Test(.tags(.unit)) func init_projectsAuthenticatedInitialState() {
        var authenticatedState = AuthSessionState.initial
        authenticatedState.isAuthenticated = true
        authenticatedState.statusMessage = "Signed in"

        let repo = ControlledAuthRepository(initial: authenticatedState)
        let viewModel = AuthViewModel(repository: repo)

        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.statusMessage == "Signed in")
    }

    @Test(.tags(.unit)) func init_projectsDeviceFlowInitialState() {
        var deviceFlowState = AuthSessionState.initial
        deviceFlowState.isLoading = true
        deviceFlowState.userCode = "ABCD-1234"
        deviceFlowState.verificationURI = "https://github.com/login/device"
        deviceFlowState.statusMessage = "Open GitHub and approve access"

        let repo = ControlledAuthRepository(initial: deviceFlowState)
        let viewModel = AuthViewModel(repository: repo)

        #expect(viewModel.isLoading == true)
        #expect(viewModel.userCode == "ABCD-1234")
        #expect(viewModel.verificationURI == "https://github.com/login/device")
        #expect(viewModel.statusMessage == "Open GitHub and approve access")
    }

    // MARK: - Publisher subscription

    @Test(.tags(.unit)) func stateUpdates_whenRepositoryPublishesNewState() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        var updatedState = AuthSessionState.initial
        updatedState.isAuthenticated = true
        updatedState.statusMessage = "Signed in"

        repo.emit(updatedState)

        // Give the Combine sink a chance to deliver on MainActor
        await Task.yield()

        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.statusMessage == "Signed in")
        #expect(viewModel.state == updatedState)
    }

    @Test(.tags(.unit)) func stateUpdates_multipleEmissions_alwaysReflectsLatest() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        var loadingState = AuthSessionState.initial
        loadingState.isLoading = true
        loadingState.statusMessage = "Waiting…"
        repo.emit(loadingState)
        await Task.yield()

        var finalState = AuthSessionState.initial
        finalState.isAuthenticated = true
        finalState.statusMessage = "Signed in"
        repo.emit(finalState)
        await Task.yield()

        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.statusMessage == "Signed in")
    }

    @Test(.tags(.unit)) func stateUpdates_withErrorState_surfacesErrorMessage() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        var errorState = AuthSessionState.initial
        errorState.errorMessage = "Session expired. Please sign in again."
        errorState.statusMessage = "Session expired"
        repo.emit(errorState)
        await Task.yield()

        #expect(viewModel.errorMessage == "Session expired. Please sign in again.")
        #expect(viewModel.statusMessage == "Session expired")
    }

    @Test(.tags(.unit)) func stateUpdates_clearingError_nilsErrorMessage() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        var errorState = AuthSessionState.initial
        errorState.errorMessage = "Something went wrong"
        repo.emit(errorState)
        await Task.yield()

        var clearedState = AuthSessionState.initial
        clearedState.errorMessage = nil
        repo.emit(clearedState)
        await Task.yield()

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Action delegation

    @Test(.tags(.unit, .async_)) func restoreSessionIfNeeded_delegatesToRepository() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        await viewModel.restoreSessionIfNeeded()

        #expect(repo.restoreCalls == 1)
        #expect(repo.startDeviceFlowCalls == 0)
        #expect(repo.pollCalls == 0)
        #expect(repo.signOutCalls == 0)
    }

    @Test(.tags(.unit, .async_)) func startDeviceFlow_delegatesToRepository() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        await viewModel.startDeviceFlow()

        #expect(repo.startDeviceFlowCalls == 1)
        #expect(repo.restoreCalls == 0)
        #expect(repo.pollCalls == 0)
        #expect(repo.signOutCalls == 0)
    }

    @Test(.tags(.unit, .async_)) func pollForAuthorization_delegatesToRepository() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        await viewModel.pollForAuthorization()

        #expect(repo.pollCalls == 1)
        #expect(repo.restoreCalls == 0)
        #expect(repo.startDeviceFlowCalls == 0)
        #expect(repo.signOutCalls == 0)
    }

    @Test(.tags(.unit)) func signOut_delegatesToRepository() {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        viewModel.signOut()

        #expect(repo.signOutCalls == 1)
        #expect(repo.restoreCalls == 0)
        #expect(repo.startDeviceFlowCalls == 0)
        #expect(repo.pollCalls == 0)
    }

    // MARK: - Multiple sequential actions

    @Test(.tags(.unit, .async_)) func sequentialActions_accumulateCallCounts() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        await viewModel.restoreSessionIfNeeded()
        await viewModel.startDeviceFlow()
        await viewModel.pollForAuthorization()
        viewModel.signOut()

        #expect(repo.restoreCalls == 1)
        #expect(repo.startDeviceFlowCalls == 1)
        #expect(repo.pollCalls == 1)
        #expect(repo.signOutCalls == 1)
    }

    @Test(.tags(.unit, .async_)) func callingRestoreTwice_delegatesTwiceToRepository() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        await viewModel.restoreSessionIfNeeded()
        await viewModel.restoreSessionIfNeeded()

        // ViewModel is transparent — it doesn't de-duplicate calls.
        // Guard-against-re-entry lives in GitHubAuthRepository.
        #expect(repo.restoreCalls == 2)
    }

    // MARK: - currentAccessToken

    @Test(.tags(.unit)) func currentAccessToken_forwardsToRepository_returnsNilByDefault() {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        #expect(viewModel.currentAccessToken() == nil)
    }

    @Test(.tags(.unit)) func currentAccessToken_forwardsToRepository_returnsInjectedToken() {
        let repo = ControlledAuthRepository(initial: .initial, accessToken: "ghp_stubToken")
        let viewModel = AuthViewModel(repository: repo)

        #expect(viewModel.currentAccessToken() == "ghp_stubToken")
    }

    // MARK: - Computed property passthrough

    @Test(.tags(.unit)) func computedProperties_matchUnderlyingState_allFields() async {
        let repo = ControlledAuthRepository(initial: .initial)
        let viewModel = AuthViewModel(repository: repo)

        var state = AuthSessionState.initial
        state.isAuthenticated = true
        state.isLoading = false
        state.statusMessage = "Signed in"
        state.errorMessage = nil
        state.userCode = "EFGH-5678"
        state.verificationURI = "https://github.com/login/device?code=EFGH-5678"
        repo.emit(state)
        await Task.yield()

        #expect(viewModel.isAuthenticated == state.isAuthenticated)
        #expect(viewModel.isLoading == state.isLoading)
        #expect(viewModel.statusMessage == state.statusMessage)
        #expect(viewModel.errorMessage == state.errorMessage)
        #expect(viewModel.userCode == state.userCode)
        #expect(viewModel.verificationURI == state.verificationURI)
    }
}

// MARK: - Test double

/// A controllable AuthRepository stub that lets tests push state updates
/// through the Combine publisher and count use-case invocations.
@MainActor
private final class ControlledAuthRepository: AuthRepository {
    private(set) var restoreCalls = 0
    private(set) var startDeviceFlowCalls = 0
    private(set) var pollCalls = 0
    private(set) var signOutCalls = 0

    private let subject: CurrentValueSubject<AuthSessionState, Never>
    private let token: String?

    init(initial: AuthSessionState, accessToken: String? = nil) {
        self.subject = CurrentValueSubject(initial)
        self.token = accessToken
    }

    /// Push a new state through the Combine publisher.
    func emit(_ state: AuthSessionState) {
        subject.send(state)
    }

    // MARK: AuthRepository

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
        token
    }
}
