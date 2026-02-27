import Foundation
import Testing
@testable import mac_copilot

/// Unit tests for `GitHubAuthService`.
///
/// All three dependencies are injected so no real I/O occurs:
/// - `sidecarClient`  — backed by `StubHTTPDataTransport` via the `httpClient:` seam
/// - `keychain`       — `InMemoryKeychainTokenStore` (in-memory, no real Keychain)
/// - `delayScheduler` — `NoOpDelayScheduler` (zero-wait sleeps for poll loops)
///
/// ## Stub transport queue layout
///
/// `SidecarHTTPClient.sendWithRetry` pings /health twice before every POST:
///   1. `ensureSidecarStartedIfUnavailable` → one health GET
///   2. `waitForSidecarReadyInternal(maxAttempts:12)` → stops at first 200
///
/// So for each substantive POST the stub needs [200 health, 200 health, POST response].
///
/// `waitForSidecarReady(maxAttempts:5)` — called directly by `restoreSessionIfNeeded`
/// — hits the same health endpoint once per attempt (5 pings maximum).
///
/// The `postEntries` helper builds the [health, health, POST] triple for one request.
/// Combine multiple `postEntries` calls to feed multi-step test flows.
@MainActor
struct GitHubAuthServiceTests {

    // MARK: - restoreSessionIfNeeded — no stored token

    @Test(.tags(.unit, .async_)) func restoreSession_noToken_setsSignInRequiredStatus() async {
        let keychain = InMemoryKeychainTokenStore()          // empty
        let service = makeService(keychain: keychain, stubResults: [])

        await service.restoreSessionIfNeeded()

        #expect(!service.isAuthenticated)
        #expect(service.statusMessage == "Sign in required")
        #expect(service.errorMessage == nil)
    }

    @Test(.tags(.unit, .async_)) func restoreSession_noToken_doesNotCallSidecar() async {
        let keychain = InMemoryKeychainTokenStore()
        let (service, transport) = makeServiceCapturingTransport(keychain: keychain, stubResults: [])

        await service.restoreSessionIfNeeded()

        // No token → exits before contacting the sidecar.
        #expect(keychain.readCallCount == 1)
        #expect(transport.callCount == 0)
    }

    // MARK: - restoreSessionIfNeeded — sidecar not ready

    @Test(.tags(.unit, .async_)) func restoreSession_sidecarNotReady_setsOfflineError() async {
        let keychain = InMemoryKeychainTokenStore(existingToken: "ghp_token")
        // waitForSidecarReady(maxAttempts:5) calls pingHealth 5 times.
        // Return 500 for every health ping so sidecar is never "ready".
        let service = makeService(keychain: keychain, stubResults: healthEntries(count: 5, statusCode: 500))

        await service.restoreSessionIfNeeded()

        #expect(!service.isAuthenticated)
        #expect(service.statusMessage.lowercased().contains("offline")
                || service.statusMessage.lowercased().contains("sidecar"))
        #expect(service.errorMessage != nil)
    }

    // MARK: - restoreSessionIfNeeded — success

    @Test(.tags(.unit, .async_)) func restoreSession_validToken_setsIsAuthenticated() async {
        let keychain = InMemoryKeychainTokenStore(existingToken: "ghp_valid")
        let authBody = """
        { "ok": true, "authenticated": true }
        """.data(using: .utf8)!

        // Stub queue:
        //  [0]   200 health → waitForSidecarReady attempt 1 (succeeds immediately)
        //  [1,2] health pair → ensureSidecar + waitForSidecarReady inside sendWithRetry
        //  [3]   200 POST   → authorize succeeds
        let service = makeService(keychain: keychain, stubResults:
            healthEntries(count: 1) + postEntries(statusCode: 200, body: authBody)
        )

        await service.restoreSessionIfNeeded()

        #expect(service.isAuthenticated)
        #expect(service.statusMessage == "Signed in")
        #expect(service.errorMessage == nil)
    }

    // MARK: - restoreSessionIfNeeded — non-recoverable error deletes token

    @Test(.tags(.unit, .async_)) func restoreSession_authFailure_deletesToken() async {
        let keychain = InMemoryKeychainTokenStore(existingToken: "ghp_expired")
        let errorBody = """
        { "ok": false, "error": "Bad credentials" }
        """.data(using: .utf8)!

        // [0] health → waitForSidecarReady succeeds
        // [1,2] health pair + [3] 401 POST → authorize fails (non-recoverable)
        let service = makeService(keychain: keychain, stubResults:
            healthEntries(count: 1) + postEntries(statusCode: 401, body: errorBody)
        )

        await service.restoreSessionIfNeeded()

        #expect(!service.isAuthenticated)
        #expect(keychain.deleteCallCount >= 1)
        #expect(keychain.storedToken == nil)
        #expect(service.errorMessage != nil)
    }

    // MARK: - restoreSessionIfNeeded — idempotent guard

    @Test(.tags(.unit, .async_)) func restoreSession_calledTwice_onlyRunsOnce() async {
        let keychain = InMemoryKeychainTokenStore()    // no token — exits early
        let (service, transport) = makeServiceCapturingTransport(keychain: keychain, stubResults: [])

        await service.restoreSessionIfNeeded()
        await service.restoreSessionIfNeeded()

        // Second call is suppressed by the `didAttemptRestore` guard.
        #expect(keychain.readCallCount == 1)
        #expect(transport.callCount == 0)
    }

    // MARK: - startDeviceFlow — missing client ID

    @Test(.tags(.unit, .async_)) func startDeviceFlow_emptyClientID_setsErrorMessage() async {
        let service = makeService(stubResults: [], clientID: "")

        await service.startDeviceFlow()

        #expect(service.errorMessage != nil)
        #expect(service.errorMessage?.contains("Client ID") == true
                || service.errorMessage?.contains("missing") == true)
        #expect(!service.isLoading)
    }

    // MARK: - startDeviceFlow — success

    @Test(.tags(.unit, .async_)) func startDeviceFlow_success_setsDeviceFlowFields() async {
        let body = startAuthJSON(deviceCode: "dev-abc", userCode: "WXYZ-1234",
                                 verificationURIComplete: "https://github.com/login/device?code=WXYZ-1234",
                                 interval: 5)
        let service = makeService(stubResults: postEntries(statusCode: 200, body: body))

        await service.startDeviceFlow()

        #expect(service.userCode == "WXYZ-1234")
        #expect(service.verificationURI == "https://github.com/login/device?code=WXYZ-1234")
        #expect(!service.isLoading)
        #expect(service.errorMessage == nil)
        #expect(service.statusMessage == "Open GitHub and approve access")
    }

    @Test(.tags(.unit, .async_)) func startDeviceFlow_prefersVerificationURIComplete() async {
        let body = startAuthJSON(deviceCode: "dev-abc", userCode: "CODE-1234",
                                 verificationURIComplete: "https://github.com/login/device?code=CODE-1234")
        let service = makeService(stubResults: postEntries(statusCode: 200, body: body))

        await service.startDeviceFlow()

        #expect(service.verificationURI == "https://github.com/login/device?code=CODE-1234")
    }

    @Test(.tags(.unit, .async_)) func startDeviceFlow_fallsBackToVerificationURIWhenCompleteAbsent() async {
        let body = startAuthJSON(deviceCode: "dev-abc", userCode: "CODE-5678")
        let service = makeService(stubResults: postEntries(statusCode: 200, body: body))

        await service.startDeviceFlow()

        #expect(service.verificationURI == "https://github.com/login/device")
    }

    @Test(.tags(.unit, .async_)) func startDeviceFlow_clampsMinimumPollIntervalToTwo() async {
        // Server returns interval: 1 — service clamps to max(1, 2) = 2.
        let body = startAuthJSON(deviceCode: "dev-abc", userCode: "ABCD-0001", interval: 1)
        let service = makeService(stubResults: postEntries(statusCode: 200, body: body))

        await service.startDeviceFlow()

        // pollInterval is private; confirm no error and userCode is set.
        #expect(service.errorMessage == nil)
        #expect(service.userCode == "ABCD-0001")
    }

    // MARK: - startDeviceFlow — error

    @Test(.tags(.unit, .async_)) func startDeviceFlow_serverError_setsErrorMessage() async {
        let body = """
        { "ok": false, "error": "invalid_client" }
        """.data(using: .utf8)!
        let service = makeService(stubResults: postEntries(statusCode: 400, body: body))

        await service.startDeviceFlow()

        #expect(service.errorMessage != nil)
        #expect(!service.isLoading)
        #expect(service.statusMessage == "Could not start sign-in")
    }

    @Test(.tags(.unit, .async_)) func startDeviceFlow_errorPath_clearsIsLoading() async {
        let body = """
        { "ok": false, "error": "bad_client" }
        """.data(using: .utf8)!
        let service = makeService(stubResults: postEntries(statusCode: 400, body: body))

        await service.startDeviceFlow()

        #expect(!service.isLoading)
    }

    // MARK: - errorMessage cleared on new attempt

    @Test(.tags(.unit, .async_)) func startDeviceFlow_clearsPreviousErrorMessage() async {
        let errorBody = """
        { "ok": false, "error": "fail" }
        """.data(using: .utf8)!
        let successBody = startAuthJSON(deviceCode: "dev-2", userCode: "CLEAR-1234")

        let service = makeService(stubResults:
            postEntries(statusCode: 500, body: errorBody) +
            postEntries(statusCode: 200, body: successBody)
        )

        await service.startDeviceFlow()
        #expect(service.errorMessage != nil)

        await service.startDeviceFlow()
        #expect(service.errorMessage == nil)
    }

    // MARK: - pollForAuthorization — no device code

    @Test(.tags(.unit, .async_)) func pollAuthorization_noDeviceCode_setsErrorMessage() async {
        let service = makeService(stubResults: [])

        await service.pollForAuthorization()

        #expect(service.errorMessage?.contains("Start sign-in") == true)
    }

    // MARK: - pollForAuthorization — authorized → saves token

    @Test(.tags(.unit, .async_)) func pollAuthorization_authorized_savesTokenToKeychain() async {
        let keychain = InMemoryKeychainTokenStore()
        let pollBody = pollAuthJSON(status: "authorized", accessToken: "ghp_newtoken")

        let service = makeService(keychain: keychain, stubResults:
            postEntries(statusCode: 200, body: startAuthJSON(deviceCode: "dev-code",
                                                             userCode: "POLL-TEST")) +
            postEntries(statusCode: 200, body: pollBody)
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(keychain.storedToken == "ghp_newtoken")
        #expect(service.isAuthenticated)
        #expect(service.statusMessage == "Signed in")
        #expect(!service.isLoading)
    }

    @Test(.tags(.unit, .async_)) func pollAuthorization_authorized_setsIsAuthenticated() async {
        let service = makeService(stubResults:
            postEntries(statusCode: 200, body: startAuthJSON(deviceCode: "dev-1",
                                                             userCode: "AUTH-1234")) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "authorized",
                                                            accessToken: "ghp_tok"))
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(service.isAuthenticated)
    }

    // MARK: - pollForAuthorization — authorization_pending → retries

    @Test(.tags(.unit, .async_)) func pollAuthorization_pendingThenAuthorized_retriesAndSucceeds() async {
        let keychain = InMemoryKeychainTokenStore()

        let service = makeService(keychain: keychain, stubResults:
            postEntries(statusCode: 200, body: startAuthJSON(deviceCode: "dev-code",
                                                             userCode: "PEND-TEST")) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "authorization_pending")) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "authorized",
                                                            accessToken: "ghp_final"))
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(keychain.storedToken == "ghp_final")
        #expect(service.isAuthenticated)
    }

    // MARK: - pollForAuthorization — slow_down increases poll interval

    @Test(.tags(.unit, .async_)) func pollAuthorization_slowDown_thenAuthorized_succeeds() async {
        let keychain = InMemoryKeychainTokenStore()

        let service = makeService(keychain: keychain, stubResults:
            postEntries(statusCode: 200, body: startAuthJSON(deviceCode: "dev-code",
                                                             userCode: "SLOW-TEST")) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "slow_down", interval: 10)) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "authorized",
                                                            accessToken: "ghp_slow_tok"))
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(keychain.storedToken == "ghp_slow_tok")
        #expect(service.isAuthenticated)
    }

    // MARK: - pollForAuthorization — access_denied

    @Test(.tags(.unit, .async_)) func pollAuthorization_accessDenied_setsErrorAndIsNotAuthenticated() async {
        let service = makeService(stubResults:
            postEntries(statusCode: 200, body: startAuthJSON(deviceCode: "dev-code",
                                                             userCode: "DENY-TEST")) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "access_denied"))
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(!service.isAuthenticated)
        #expect(!service.isLoading)
        #expect(service.errorMessage != nil)
        #expect(service.statusMessage == "Sign-in failed")
    }

    // MARK: - pollForAuthorization — expired_token

    @Test(.tags(.unit, .async_)) func pollAuthorization_expiredToken_setsErrorAndIsNotAuthenticated() async {
        let service = makeService(stubResults:
            postEntries(statusCode: 200, body: startAuthJSON(deviceCode: "dev-code",
                                                             userCode: "EXPIRY-TEST")) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "expired_token"))
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(!service.isAuthenticated)
        #expect(!service.isLoading)
        #expect(service.errorMessage != nil)
    }

    // MARK: - pollForAuthorization — authorized but missing access_token

    @Test(.tags(.unit, .async_)) func pollAuthorization_authorizedWithNoToken_setsErrorMessage() async {
        // "authorized" response without an access_token field
        let service = makeService(stubResults:
            postEntries(statusCode: 200, body: startAuthJSON(deviceCode: "dev-code",
                                                             userCode: "MISSING-TOK")) +
            postEntries(statusCode: 200, body: pollAuthJSON(status: "authorized"))
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(!service.isAuthenticated)
        #expect(service.errorMessage != nil)
    }

    // MARK: - pollForAuthorization — recoverable errors exhaust retry budget

    @Test(.tags(.unit, .async_)) func pollAuthorization_persistentRecoverableError_setsFailedStatus() async {
        // After startDeviceFlow every subsequent transport call throws a connection
        // error.  The service allows up to 5 transient failures; SidecarHTTPClient's
        // own AsyncRetry allows 3 inner attempts.  50 errors is more than enough to
        // exhaust all layers.
        let startBody = startAuthJSON(deviceCode: "dev-code", userCode: "RETRY-FAIL")
        let connectionErrors: [Result<(Data, URLResponse), Error>] = Array(
            repeating: .failure(URLError(.cannotConnectToHost)),
            count: 50
        )
        let service = makeService(stubResults:
            postEntries(statusCode: 200, body: startBody) + connectionErrors
        )

        await service.startDeviceFlow()
        await service.pollForAuthorization()

        #expect(!service.isAuthenticated)
        #expect(!service.isLoading)
        #expect(service.statusMessage == "Sign-in failed")
        #expect(service.errorMessage != nil)
    }

    // MARK: - signOut

    @Test(.tags(.unit)) func signOut_clearsAuthenticationState() {
        let keychain = InMemoryKeychainTokenStore(existingToken: "ghp_existing")
        let service = makeService(keychain: keychain, stubResults: [])

        service.signOut()

        #expect(!service.isAuthenticated)
        #expect(service.userCode == nil)
        #expect(service.verificationURI == nil)
        #expect(service.statusMessage == "Signed out")
        #expect(keychain.storedToken == nil)
    }

    @Test(.tags(.unit)) func signOut_deletesKeychainToken() {
        let keychain = InMemoryKeychainTokenStore(existingToken: "ghp_tok")
        let service = makeService(keychain: keychain, stubResults: [])

        service.signOut()

        #expect(keychain.deleteCallCount == 1)
        #expect(keychain.storedToken == nil)
    }

    @Test(.tags(.unit, .async_)) func signOut_resetsDidAttemptRestoreFlag() async {
        let keychain = InMemoryKeychainTokenStore()
        let (service, _) = makeServiceCapturingTransport(keychain: keychain, stubResults: [])

        // First restore: sets didAttemptRestore = true.
        await service.restoreSessionIfNeeded()
        #expect(keychain.readCallCount == 1)

        service.signOut()

        // signOut resets didAttemptRestore → restore runs again.
        await service.restoreSessionIfNeeded()
        #expect(keychain.readCallCount == 2)
    }

    // MARK: - currentAccessToken

    @Test(.tags(.unit)) func currentAccessToken_returnsKeychainToken() {
        let keychain = InMemoryKeychainTokenStore(existingToken: "ghp_stored")
        let service = makeService(keychain: keychain, stubResults: [])

        #expect(service.currentAccessToken() == "ghp_stored")
    }

    @Test(.tags(.unit)) func currentAccessToken_returnsNilWhenKeychainEmpty() {
        let service = makeService(stubResults: [])

        #expect(service.currentAccessToken() == nil)
    }
}

// MARK: - JSON body builders

/// Minimal `StartAuthResponse` JSON.
private func startAuthJSON(
    deviceCode: String,
    userCode: String,
    verificationURIComplete: String? = nil,
    interval: Int? = nil
) -> Data {
    var parts: [String] = [
        "\"ok\": true",
        "\"device_code\": \"\(deviceCode)\"",
        "\"user_code\": \"\(userCode)\"",
        "\"verification_uri\": \"https://github.com/login/device\"",
    ]
    if let c = verificationURIComplete { parts.append("\"verification_uri_complete\": \"\(c)\"") }
    if let i = interval               { parts.append("\"interval\": \(i)") }
    return ("{ " + parts.joined(separator: ", ") + " }").data(using: .utf8)!
}

/// Minimal `PollAuthResponse` JSON.
private func pollAuthJSON(
    status: String,
    accessToken: String? = nil,
    interval: Int? = nil
) -> Data {
    var parts: [String] = [
        "\"ok\": true",
        "\"status\": \"\(status)\"",
    ]
    if let t = accessToken { parts.append("\"access_token\": \"\(t)\"") }
    if let i = interval    { parts.append("\"interval\": \(i)") }
    return ("{ " + parts.joined(separator: ", ") + " }").data(using: .utf8)!
}

// MARK: - Stub queue helpers

typealias StubEntry = Result<(Data, URLResponse), Error>

/// Returns `count` health-ping stub entries with `statusCode`.
private func healthEntries(count: Int, statusCode: Int = 200) -> [StubEntry] {
    let url = URL(string: "http://127.0.0.1:7878/health")!
    return (0 ..< count).map { _ in
        .success((Data(), makeHTTPResponse(statusCode: statusCode, url: url)))
    }
}

/// Builds the three-entry stub sequence for ONE `SidecarHTTPClient` POST:
///   [0] 200 health → ensureSidecarStartedIfUnavailable
///   [1] 200 health → waitForSidecarReadyInternal (first attempt succeeds)
///   [2] the actual POST response
///
/// Chain multiple `postEntries` calls to feed multi-step flows.
private func postEntries(statusCode: Int, body: Data) -> [StubEntry] {
    let baseURL = URL(string: "http://127.0.0.1:7878")!
    return healthEntries(count: 2) + [
        .success((body, makeHTTPResponse(statusCode: statusCode, url: baseURL)))
    ]
}

// MARK: - Factory

/// Creates a `GitHubAuthService` backed by a pre-loaded `StubHTTPDataTransport`.
@MainActor
private func makeService(
    keychain: KeychainTokenStoring = InMemoryKeychainTokenStore(),
    stubResults: [StubEntry],
    clientID: String = "test-client-id"
) -> GitHubAuthService {
    let (service, _) = makeServiceCapturingTransport(keychain: keychain,
                                                     stubResults: stubResults,
                                                     clientID: clientID)
    return service
}

/// Like `makeService` but also returns the `StubHTTPDataTransport` for inspection.
@MainActor
private func makeServiceCapturingTransport(
    keychain: KeychainTokenStoring = InMemoryKeychainTokenStore(),
    stubResults: [StubEntry],
    clientID: String = "test-client-id"
) -> (GitHubAuthService, StubHTTPDataTransport) {
    let baseURL = URL(string: "http://127.0.0.1:7878")!
    let lifecycle = RecordingLifecycleManager()
    let transport = StubHTTPDataTransport(results: stubResults)

    let httpClient = SidecarHTTPClient(
        baseURL: baseURL,
        sidecarLifecycle: lifecycle,
        transport: transport,
        delayScheduler: NoOpDelayScheduler()
    )

    let authClient = SidecarAuthClient(
        baseURL: baseURL,
        sidecarLifecycle: lifecycle,
        httpClient: httpClient
    )

    let service = GitHubAuthService(
        sidecarClient: authClient,
        keychain: keychain,
        delayScheduler: NoOpDelayScheduler(),
        clientID: clientID
    )

    return (service, transport)
}
