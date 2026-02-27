import Foundation
import Testing
@testable import mac_copilot

/// Tests for SidecarAuthClient behaviour.
///
/// SidecarAuthClient wraps SidecarHTTPClient internally and does not expose a
/// transport injection seam.  The HTTP-layer contract (JSON encode/decode, status
/// code mapping) is exercised in AuthAPIModelsTests and, for the underlying
/// transport, in SidecarLifecycleTests.
///
/// What we CAN test directly on SidecarAuthClient without a network stub:
///   • isRecoverableConnectionError — pure classification logic, no I/O.
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
}

// MARK: - Factory

/// Creates a SidecarAuthClient with a no-op lifecycle manager.
/// The client will point at the standard localhost address but no real
/// network connections are made by the tests in this file.
@MainActor
private func makeClient() -> SidecarAuthClient {
    SidecarAuthClient(
        baseURL: URL(string: "http://127.0.0.1:7878")!,
        sidecarLifecycle: RecordingLifecycleManager()
    )
}
