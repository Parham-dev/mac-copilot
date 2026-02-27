import Foundation
import Testing
@testable import mac_copilot

struct RecoverableNetworkErrorTests {
    @Test(.tags(.unit)) func cannotConnectToHostIsConnectionRelated() {
        let error = URLError(.cannotConnectToHost)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func networkConnectionLostIsConnectionRelated() {
        let error = URLError(.networkConnectionLost)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func timedOutIsConnectionRelated() {
        let error = URLError(.timedOut)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func notConnectedToInternetIsConnectionRelated() {
        let error = URLError(.notConnectedToInternet)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func cannotFindHostIsConnectionRelated() {
        let error = URLError(.cannotFindHost)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func badServerResponseIsConnectionRelated() {
        let error = URLError(.badServerResponse)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func cancelled_isNotConnectionRelated() {
        let error = URLError(.cancelled)
        #expect(!RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func cannotParseResponseIsConnectionRelated() {
        let error = URLError(.cannotParseResponse)
        #expect(RecoverableNetworkError.isConnectionRelated(error))
    }

    @Test(.tags(.unit)) func nonURLErrorIsNotConnectionRelated() {
        let error = NSError(domain: "com.example", code: 42, userInfo: nil)
        #expect(!RecoverableNetworkError.isConnectionRelated(error))
    }
}
