import Foundation
import Testing
@testable import mac_copilot

struct AuthSessionStateTests {

    // MARK: - initial constant

    @Test(.tags(.unit)) func initial_isNotAuthenticated() {
        #expect(AuthSessionState.initial.isAuthenticated == false)
    }

    @Test(.tags(.unit)) func initial_isNotLoading() {
        #expect(AuthSessionState.initial.isLoading == false)
    }

    @Test(.tags(.unit)) func initial_statusMessageIsSignInRequired() {
        #expect(AuthSessionState.initial.statusMessage == "Sign in required")
    }

    @Test(.tags(.unit)) func initial_errorMessageIsNil() {
        #expect(AuthSessionState.initial.errorMessage == nil)
    }

    @Test(.tags(.unit)) func initial_userCodeIsNil() {
        #expect(AuthSessionState.initial.userCode == nil)
    }

    @Test(.tags(.unit)) func initial_verificationURIIsNil() {
        #expect(AuthSessionState.initial.verificationURI == nil)
    }

    // MARK: - Equatable

    @Test(.tags(.unit)) func equatable_twoInitialStatesAreEqual() {
        #expect(AuthSessionState.initial == AuthSessionState.initial)
    }

    @Test(.tags(.unit)) func equatable_differsByIsAuthenticated() {
        var other = AuthSessionState.initial
        other.isAuthenticated = true
        #expect(AuthSessionState.initial != other)
    }

    @Test(.tags(.unit)) func equatable_differsByIsLoading() {
        var other = AuthSessionState.initial
        other.isLoading = true
        #expect(AuthSessionState.initial != other)
    }

    @Test(.tags(.unit)) func equatable_differsByStatusMessage() {
        var other = AuthSessionState.initial
        other.statusMessage = "Signed in"
        #expect(AuthSessionState.initial != other)
    }

    @Test(.tags(.unit)) func equatable_differsByErrorMessage() {
        var other = AuthSessionState.initial
        other.errorMessage = "Something went wrong"
        #expect(AuthSessionState.initial != other)
    }

    @Test(.tags(.unit)) func equatable_differsByUserCode() {
        var other = AuthSessionState.initial
        other.userCode = "ABCD-1234"
        #expect(AuthSessionState.initial != other)
    }

    @Test(.tags(.unit)) func equatable_differsByVerificationURI() {
        var other = AuthSessionState.initial
        other.verificationURI = "https://github.com/login/device"
        #expect(AuthSessionState.initial != other)
    }

    // MARK: - Mutability

    @Test(.tags(.unit)) func canTransitionToAuthenticatedState() {
        var state = AuthSessionState.initial
        state.isAuthenticated = true
        state.statusMessage = "Signed in"
        state.errorMessage = nil

        #expect(state.isAuthenticated)
        #expect(state.statusMessage == "Signed in")
        #expect(state.errorMessage == nil)
    }

    @Test(.tags(.unit)) func canTransitionToDeviceFlowState() {
        var state = AuthSessionState.initial
        state.isLoading = true
        state.userCode = "WXYZ-5678"
        state.verificationURI = "https://github.com/login/device"
        state.statusMessage = "Open GitHub and approve access"

        #expect(state.isLoading)
        #expect(state.userCode == "WXYZ-5678")
        #expect(state.verificationURI == "https://github.com/login/device")
    }

    @Test(.tags(.unit)) func canRepresentErrorState() {
        var state = AuthSessionState.initial
        state.errorMessage = "GitHub sign-in was denied."
        state.statusMessage = "Sign-in failed"
        state.isLoading = false

        #expect(state.errorMessage == "GitHub sign-in was denied.")
        #expect(!state.isLoading)
        #expect(!state.isAuthenticated)
    }
}
