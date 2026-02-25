import Foundation
import Combine

@MainActor
final class GitHubAuthService: ObservableObject {
    private static let configuredClientID = "Ov23lisoGOGOPveFYywW"

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var statusMessage = "Sign in required"
    @Published var errorMessage: String?
    @Published var userCode: String?
    @Published var verificationURI: String?
    @Published private(set) var clientID: String

    private var deviceCode: String?
    private var pollInterval: Int = 5
    private var didAttemptRestore = false
    private var isRestoring = false

    private let keychain = KeychainTokenStore()
    private let sidecarClient: SidecarAuthClient

    init(sidecarClient: SidecarAuthClient) {
        self.sidecarClient = sidecarClient
        self.clientID = Self.configuredClientID
    }

    func restoreSessionIfNeeded() async {
        guard !didAttemptRestore, !isRestoring else { return }
        didAttemptRestore = true
        isRestoring = true
        defer { isRestoring = false }

        guard let token = keychain.readToken() else {
            statusMessage = "Sign in required"
            return
        }

        statusMessage = "Restoring session…"
        errorMessage = nil

        let sidecarReady = await sidecarClient.waitForSidecarReady(maxAttempts: 5, delaySeconds: 0.35)
        guard sidecarReady else {
            isAuthenticated = false
            statusMessage = "Local sidecar is offline. Relaunch app to retry."
            errorMessage = "Could not connect to 127.0.0.1:7878"
            return
        }

        let maxAttempts = 2
        for attempt in 1 ... maxAttempts {
            do {
                _ = try await sidecarClient.authorize(token: token)
                isAuthenticated = true
                statusMessage = "Signed in"
                return
            } catch {
                if sidecarClient.isRecoverableConnectionError(error), attempt < maxAttempts {
                    statusMessage = "Reconnecting to local sidecar…"
                    let retryDelay = UInt64(300_000_000 * UInt64(attempt))
                    try? await Task.sleep(nanoseconds: retryDelay)
                    continue
                }

                if sidecarClient.isRecoverableConnectionError(error) {
                    isAuthenticated = false
                    statusMessage = "Local sidecar is offline. Relaunch app to retry."
                    errorMessage = error.localizedDescription
                    return
                }

                keychain.deleteToken()
                isAuthenticated = false
                statusMessage = "Session expired. Please sign in again."
                errorMessage = error.localizedDescription
                return
            }
        }

        isAuthenticated = false
        statusMessage = "Sign in required"
    }

    func startDeviceFlow() async {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientID.isEmpty else {
            errorMessage = "App OAuth Client ID is missing. Contact support."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await sidecarClient.startAuth(clientId: trimmedClientID)
            deviceCode = response.deviceCode
            userCode = response.userCode
            verificationURI = response.verificationURIComplete ?? response.verificationURI
            pollInterval = max(response.interval ?? 5, 2)
            statusMessage = "Open GitHub and approve access"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Could not start sign-in"
        }

        isLoading = false
    }

    func pollForAuthorization() async {
        guard let deviceCode else {
            errorMessage = "Start sign-in first"
            return
        }

        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientID.isEmpty else {
            errorMessage = "Client ID is required"
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = "Waiting for GitHub approval…"

        var transientFailures = 0

        while true {
            do {
                let response = try await sidecarClient.pollAuth(clientId: trimmedClientID, deviceCode: deviceCode)
                transientFailures = 0

                switch response.status {
                case "authorized":
                    guard let token = response.accessToken else {
                        throw AuthError.missingToken
                    }
                    try keychain.saveToken(token)
                    isAuthenticated = true
                    statusMessage = "Signed in"
                    isLoading = false
                    return
                case "authorization_pending":
                    try await waitForPoll(seconds: response.interval ?? pollInterval)
                case "slow_down":
                    pollInterval += 5
                    try await waitForPoll(seconds: response.interval ?? pollInterval)
                case "access_denied":
                    throw AuthError.accessDenied
                case "expired_token":
                    throw AuthError.codeExpired
                default:
                    throw AuthError.unexpectedStatus(response.status)
                }
            } catch {
                if sidecarClient.isRecoverableConnectionError(error), transientFailures < 5 {
                    transientFailures += 1
                    statusMessage = "Reconnecting to local sidecar…"
                    _ = await sidecarClient.waitForSidecarReady(maxAttempts: 4, delaySeconds: 0.5)
                    try? await waitForPoll(seconds: 1)
                    continue
                }

                isLoading = false
                isAuthenticated = false
                errorMessage = error.localizedDescription
                statusMessage = "Sign-in failed"
                return
            }
        }
    }

    func signOut() {
        keychain.deleteToken()
        isAuthenticated = false
        userCode = nil
        verificationURI = nil
        deviceCode = nil
        didAttemptRestore = false
        statusMessage = "Signed out"
    }

    func currentAccessToken() -> String? {
        keychain.readToken()
    }

    private func waitForPoll(seconds: Int) async throws {
        let clamped = max(seconds, 1)
        try await Task.sleep(nanoseconds: UInt64(clamped) * 1_000_000_000)
    }
}
