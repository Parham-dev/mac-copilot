import Foundation
import Testing
@testable import mac_copilot

struct RecoverableNetworkErrorTests {
    @Test func cannotConnectToHostIsConnectionRelated() {
        let error = URLError(.cannotConnectToHost)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test func networkConnectionLostIsConnectionRelated() {
        let error = URLError(.networkConnectionLost)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test func timedOutIsConnectionRelated() {
        let error = URLError(.timedOut)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test func notConnectedToInternetIsConnectionRelated() {
        let error = URLError(.notConnectedToInternet)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test func cannotFindHostIsConnectionRelated() {
        let error = URLError(.cannotFindHost)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test func badServerResponseIsConnectionRelated() {
        let error = URLError(.badServerResponse)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test func cancelled_isNotConnectionRelated() {
        let error = URLError(.cancelled)
        #expect(!RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test func nonURLErrorIsNotConnectionRelated() {
        let error = NSError(domain: "com.example", code: 42, userInfo: nil)
        #expect(!RecoverableNetworkError.isConnectionRelated(error))
    }
}
