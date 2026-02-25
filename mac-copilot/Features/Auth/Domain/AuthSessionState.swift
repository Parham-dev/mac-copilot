import Foundation

struct AuthSessionState: Equatable {
    var isAuthenticated: Bool
    var isLoading: Bool
    var statusMessage: String
    var errorMessage: String?
    var userCode: String?
    var verificationURI: String?

    static let initial = AuthSessionState(
        isAuthenticated: false,
        isLoading: false,
        statusMessage: "Sign in required",
        errorMessage: nil,
        userCode: nil,
        verificationURI: nil
    )
}
