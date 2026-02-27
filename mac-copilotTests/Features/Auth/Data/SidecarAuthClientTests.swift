import Foundation
import Testing
@testable import mac_copilot

/// Tests for SidecarAuthClient behaviour.
///
/// ## isRecoverableConnectionError
/// Pure classification logic — tested without any network I/O.
///
/// ## HTTP / JSON contract
/// Now that `SidecarAuthClient` accepts `httpClient: SidecarHTTPClient?`, the
/// full POST/decode pipeline can be exercised with a `StubHTTPDataTransport`.
///
/// SidecarHTTPClient pings /health before every request.  `makeClientStack`
/// therefore interleaves a 200 health response before every substantive
/// response in the stub queue.
@MainActor
struct SidecarAuthClientTests {

    // MARK: - isRecoverableConnectionError

    @Test(.tags(.unit)) func isRecoverable_trueForCannotConnectToHost() {
        let client = makeClient()
        #expect(client.isRecoverableConnectionError(URLError(.cannotConnectToHost)))
    }

    @Test(.tags(.unit)) func isRecoverable_trueForNetworkConnectionLost() {
        let client = makeClient()
        #expect(client.isRecoverableConnectionError(URLError(.networkConnectionLost)))
    }

    @Test(.tags(.unit)) func isRecoverable_trueForNotConnectedToInternet() {
        let client = makeClient()
        #expect(client.isRecoverableConnectionError(URLError(.notConnectedToInternet)))
    }

    @Test(.tags(.unit)) func isRecoverable_trueForTimedOut() {
        let client = makeClient()
        #expect(client.isRecoverableConnectionError(URLError(.timedOut)))
    }

    @Test(.tags(.unit)) func isRecoverable_trueForCannotFindHost() {
        let client = makeClient()
        #expect(client.isRecoverableConnectionError(URLError(.cannotFindHost)))
    }

    @Test(.tags(.unit)) func isRecoverable_falseForCancelled() {
        let client = makeClient()
        #expect(!client.isRecoverableConnectionError(URLError(.cancelled)))
    }

    @Test(.tags(.unit)) func isRecoverable_falseForBadURL() {
        let client = makeClient()
        #expect(!client.isRecoverableConnectionError(URLError(.badURL)))
    }

    @Test(.tags(.unit)) func isRecoverable_falseForArbitraryNSError() {
        let client = makeClient()
        let arbitrary = NSError(domain: "com.test", code: 9999)
        #expect(!client.isRecoverableConnectionError(arbitrary))
    }

    @Test(.tags(.unit)) func isRecoverable_trueForBadServerResponse() {
        let client = makeClient()
        #expect(client.isRecoverableConnectionError(URLError(.badServerResponse)))
    }

    @Test(.tags(.unit)) func isRecoverable_trueForCannotParseResponse() {
        let client = makeClient()
        #expect(client.isRecoverableConnectionError(URLError(.cannotParseResponse)))
    }

    // MARK: - Multiple error types produce consistent results

    @Test(.tags(.unit)) func recoverableErrors_allReturnTrue() {
        let client = makeClient()
        let recoverableErrors: [Error] = [
            URLError(.cannotConnectToHost),
            URLError(.networkConnectionLost),
            URLError(.notConnectedToInternet),
            URLError(.timedOut),
            URLError(.cannotFindHost),
            URLError(.badServerResponse),
            URLError(.cannotParseResponse),
        ]

        for error in recoverableErrors {
            #expect(
                client.isRecoverableConnectionError(error),
                "Expected \(error) to be recoverable"
            )
        }
    }

    @Test(.tags(.unit)) func nonRecoverableErrors_allReturnFalse() {
        let client = makeClient()
        let nonRecoverableErrors: [Error] = [
            URLError(.cancelled),
            URLError(.badURL),
            URLError(.fileDoesNotExist),
            NSError(domain: "com.example", code: 0),
            NSError(domain: NSPOSIXErrorDomain, code: 1),
        ]

        for error in nonRecoverableErrors {
            #expect(
                !client.isRecoverableConnectionError(error),
                "Expected \(error) to be non-recoverable"
            )
        }
    }

    // MARK: - authorize

    @Test(.tags(.unit, .async_)) func authorize_success_decodesAuthResponse() async throws {
        let body = """
        { "ok": true, "authenticated": true }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(200, body)])

        let response = try await client.authorize(token: "ghp_token")

        #expect(response.ok == true)
        #expect(response.authenticated == true)
    }

    @Test(.tags(.unit, .async_)) func authorize_http404_throwsOutOfDateError() async {
        let (client, _) = makeClientStack(responses: [(404, Data())])

        await #expect(throws: AuthError.self) {
            _ = try await client.authorize(token: "ghp_token")
        }
    }

    @Test(.tags(.unit, .async_)) func authorize_http500_withAPIErrorBody_throwsServerError() async throws {
        let body = """
        { "ok": false, "error": "Internal server error" }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(500, body)])

        do {
            _ = try await client.authorize(token: "ghp_token")
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthError {
            if case .server(let message) = error {
                #expect(message == "Internal server error")
            } else {
                Issue.record("Expected AuthError.server but got \(error)")
            }
        }
    }

    @Test(.tags(.unit, .async_)) func authorize_http500_withoutAPIErrorBody_throwsHTTPStatusError() async {
        let body = Data("not json".utf8)
        let (client, _) = makeClientStack(responses: [(500, body)])

        do {
            _ = try await client.authorize(token: "ghp_token")
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthError {
            if case .server(let message) = error {
                #expect(message == "HTTP 500")
            } else {
                Issue.record("Expected AuthError.server but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test(.tags(.unit, .async_)) func authorize_http200_withUndecodableBody_throwsUnexpectedResponseError() async {
        let body = Data("not json".utf8)
        let (client, _) = makeClientStack(responses: [(200, body)])

        do {
            _ = try await client.authorize(token: "ghp_token")
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthError {
            if case .server(let message) = error {
                #expect(message.contains("Unexpected response"))
            } else {
                Issue.record("Expected AuthError.server but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - startAuth

    @Test(.tags(.unit, .async_)) func startAuth_success_decodesStartAuthResponse() async throws {
        let body = """
        {
            "ok": true,
            "device_code": "dev-abc",
            "user_code": "WXYZ-1234",
            "verification_uri": "https://github.com/login/device",
            "verification_uri_complete": "https://github.com/login/device?code=WXYZ-1234",
            "interval": 5
        }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(200, body)])

        let response = try await client.startAuth(clientId: "client-123")

        #expect(response.ok == true)
        #expect(response.deviceCode == "dev-abc")
        #expect(response.userCode == "WXYZ-1234")
        #expect(response.verificationURI == "https://github.com/login/device")
        #expect(response.verificationURIComplete == "https://github.com/login/device?code=WXYZ-1234")
        #expect(response.interval == 5)
    }

    @Test(.tags(.unit, .async_)) func startAuth_success_withoutOptionalFields() async throws {
        let body = """
        {
            "ok": true,
            "device_code": "dev-xyz",
            "user_code": "ABCD-5678",
            "verification_uri": "https://github.com/login/device"
        }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(200, body)])

        let response = try await client.startAuth(clientId: "client-456")

        #expect(response.verificationURIComplete == nil)
        #expect(response.interval == nil)
    }

    @Test(.tags(.unit, .async_)) func startAuth_http404_throwsOutOfDateError() async {
        let (client, _) = makeClientStack(responses: [(404, Data())])

        do {
            _ = try await client.startAuth(clientId: "client-123")
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthError {
            if case .server(let message) = error {
                #expect(message.contains("out of date"))
            } else {
                Issue.record("Expected AuthError.server but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test(.tags(.unit, .async_)) func startAuth_http500_withAPIErrorBody_embedsErrorMessage() async throws {
        let body = """
        { "ok": false, "error": "Rate limit exceeded" }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(500, body)])

        do {
            _ = try await client.startAuth(clientId: "client-123")
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthError {
            if case .server(let message) = error {
                #expect(message == "Rate limit exceeded")
            } else {
                Issue.record("Expected AuthError.server but got \(error)")
            }
        }
    }

    // MARK: - pollAuth

    @Test(.tags(.unit, .async_)) func pollAuth_authorized_decodesAccessToken() async throws {
        let body = """
        {
            "ok": true,
            "status": "authorized",
            "access_token": "ghp_realtoken",
            "interval": 5
        }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(200, body)])

        let response = try await client.pollAuth(clientId: "client-123", deviceCode: "dev-code")

        #expect(response.status == "authorized")
        #expect(response.accessToken == "ghp_realtoken")
        #expect(response.interval == 5)
    }

    @Test(.tags(.unit, .async_)) func pollAuth_authorizationPending_returnsNilToken() async throws {
        let body = """
        {
            "ok": true,
            "status": "authorization_pending"
        }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(200, body)])

        let response = try await client.pollAuth(clientId: "client-123", deviceCode: "dev-code")

        #expect(response.status == "authorization_pending")
        #expect(response.accessToken == nil)
        #expect(response.interval == nil)
    }

    @Test(.tags(.unit, .async_)) func pollAuth_slowDown_returnsSlowDownStatus() async throws {
        let body = """
        {
            "ok": true,
            "status": "slow_down",
            "interval": 10
        }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(200, body)])

        let response = try await client.pollAuth(clientId: "client-123", deviceCode: "dev-code")

        #expect(response.status == "slow_down")
        #expect(response.interval == 10)
    }

    @Test(.tags(.unit, .async_)) func pollAuth_http500_withAPIError_throwsServerError() async {
        let body = """
        { "ok": false, "error": "device_code expired" }
        """.data(using: .utf8)!
        let (client, _) = makeClientStack(responses: [(500, body)])

        do {
            _ = try await client.pollAuth(clientId: "client-123", deviceCode: "dev-code")
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthError {
            if case .server(let message) = error {
                #expect(message == "device_code expired")
            } else {
                Issue.record("Expected AuthError.server but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test(.tags(.unit, .async_)) func pollAuth_http200_withUndecodableBody_throwsUnexpectedResponseError() async {
        let body = Data("garbage".utf8)
        let (client, _) = makeClientStack(responses: [(200, body)])

        do {
            _ = try await client.pollAuth(clientId: "client-123", deviceCode: "dev-code")
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthError {
            if case .server(let message) = error {
                #expect(message.contains("Unexpected response"))
            } else {
                Issue.record("Expected AuthError.server but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Factories

/// Creates a `SidecarAuthClient` with a no-op lifecycle manager.
/// No real network connections are made by the `isRecoverableConnectionError` tests.
@MainActor
private func makeClient() -> SidecarAuthClient {
    SidecarAuthClient(
        baseURL: URL(string: "http://127.0.0.1:7878")!,
        sidecarLifecycle: RecordingLifecycleManager()
    )
}

/// Creates a `SidecarAuthClient` backed by a stub transport.
///
/// `SidecarHTTPClient.sendWithRetry` pings /health before each real request
/// (in `ensureSidecarStartedIfUnavailable` + `waitForSidecarReadyInternal`).
/// For each substantive response we therefore also need to supply a 200 health
/// ping response so the preflight succeeds without real I/O.
///
/// The stub queue layout for a single substantive call:
///   [0] → 200 health ping (ensureSidecarStarted)
///   [1] → 200 health ping (waitForSidecarReadyInternal attempt 1)
///   [2] → the actual POST response
@MainActor
private func makeClientStack(
    responses: [(Int, Data)]
) -> (SidecarAuthClient, StubHTTPDataTransport) {
    let baseURL = URL(string: "http://127.0.0.1:7878")!
    let healthURL = baseURL.appendingPathComponent("health")

    // For each substantive response, prepend two successful health ping responses.
    var stubResults: [Result<(Data, URLResponse), Error>] = []
    for (statusCode, body) in responses {
        let healthResponse = makeHTTPResponse(statusCode: 200, url: healthURL)
        stubResults.append(.success((Data(), healthResponse)))

        let healthResponse2 = makeHTTPResponse(statusCode: 200, url: healthURL)
        stubResults.append(.success((Data(), healthResponse2)))

        let actualResponse = makeHTTPResponse(statusCode: statusCode, url: baseURL)
        stubResults.append(.success((body, actualResponse)))
    }

    let transport = StubHTTPDataTransport(results: stubResults)
    let lifecycle = RecordingLifecycleManager()

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

    return (authClient, transport)
}
