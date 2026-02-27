import Foundation
import Testing
@testable import mac_copilot

// MARK: - NormalizedIDList

struct NormalizedIDListTests {
    @Test func deduplicatesExactDuplicates() {
        let result = NormalizedIDList.from(["gpt-5", "gpt-5", "claude"])
        #expect(result == ["claude", "gpt-5"])
    }

    @Test func trimsWhitespace() {
        let result = NormalizedIDList.from(["  gpt-5 ", "\tclaude\n"])
        #expect(result == ["claude", "gpt-5"])
    }

    @Test func filtersEmptyStrings() {
        let result = NormalizedIDList.from(["gpt-5", "", "   ", "claude"])
        #expect(result == ["claude", "gpt-5"])
    }

    @Test func sortsCaseInsensitively() {
        let result = NormalizedIDList.from(["Zebra", "apple", "Mango"])
        #expect(result == ["apple", "Mango", "Zebra"])
    }

    @Test func returnsEmptyForEmptyInput() {
        #expect(NormalizedIDList.from([]).isEmpty)
    }

    @Test func preservesCaseButDeduplicatesExactMatches() {
        let result = NormalizedIDList.from(["GPT-5", "gpt-5"])
        #expect(result.count == 2)
        #expect(Set(result) == Set(["GPT-5", "gpt-5"]))
    }
}

// MARK: - UserFacingErrorMapper

struct UserFacingErrorMapperTests {
    @Test func returnsDescriptionForPlainError() {
        let error = SimpleError(message: "Something went wrong")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Something went wrong")
    }

    @Test func returnsFallbackWhenDescriptionStartsWithOperationCouldntBeCompleted() {
        let error = SimpleError(message: "The operation couldn't be completed. (Domain error 42.)")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test func returnsFallbackWhenDescriptionContainsErrorDomain() {
        let error = SimpleError(message: "Error Domain=NSURLErrorDomain Code=-1009")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test func returnsFallbackForEmptyDescription() {
        let error = SimpleError(message: "")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test func returnsFallbackForWhitespaceOnlyDescription() {
        let error = SimpleError(message: "   ")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test func returnsMessageWhenDescriptionIsUserFriendly() {
        let error = SimpleError(message: "Connection timed out. Please try again.")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback")
        #expect(result == "Connection timed out. Please try again.")
    }
}

private struct SimpleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - RecoverableNetworkError

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

// MARK: - AsyncRetry

struct AsyncRetryTests {
    @Test func succeedsOnFirstAttempt() async throws {
        var callCount = 0
        let result = try await AsyncRetry.run(
            maxAttempts: 3,
            shouldRetry: { _, _ in true }
        ) {
            callCount += 1
            return 42
        }
        #expect(result == 42)
        #expect(callCount == 1)
    }

    @Test func retriesAndSucceedsOnSecondAttempt() async throws {
        var callCount = 0
        let result = try await AsyncRetry.run(
            maxAttempts: 3,
            shouldRetry: { _, _ in true }
        ) {
            callCount += 1
            if callCount < 2 { throw URLError(.cannotConnectToHost) }
            return "ok"
        }
        #expect(result == "ok")
        #expect(callCount == 2)
    }

    @Test func throwsAfterExhaustingMaxAttempts() async {
        var callCount = 0
        await #expect(throws: (any Error).self) {
            try await AsyncRetry.run(
                maxAttempts: 3,
                shouldRetry: { _, _ in true }
            ) {
                callCount += 1
                throw URLError(.cannotConnectToHost)
            }
        }
        #expect(callCount == 3)
    }

    @Test func stopsRetryingWhenShouldRetryReturnsFalse() async {
        var callCount = 0
        await #expect(throws: (any Error).self) {
            try await AsyncRetry.run(
                maxAttempts: 5,
                shouldRetry: { _, attempt in attempt < 2 }
            ) {
                callCount += 1
                throw URLError(.badServerResponse)
            }
        }
        #expect(callCount == 2)
    }

    @Test func callsOnRetryCallback() async throws {
        var retryAttempts: [Int] = []
        _ = try? await AsyncRetry.run(
            maxAttempts: 3,
            shouldRetry: { _, _ in true },
            onRetry: { _, attempt in retryAttempts.append(attempt) }
        ) {
            throw URLError(.timedOut)
        } as Int
        #expect(retryAttempts == [1, 2])
    }

    @Test func runUntil_returnsResultOnFirstSuccess() async {
        var callCount = 0
        let result = await AsyncRetry.runUntil(
            maxAttempts: 5,
            isSuccess: { $0 == 10 }
        ) {
            callCount += 1
            return 10
        }
        #expect(result == 10)
        #expect(callCount == 1)
    }

    @Test func runUntil_retriesUntilSuccessConditionMet() async {
        var callCount = 0
        let result = await AsyncRetry.runUntil(
            maxAttempts: 5,
            isSuccess: { $0 >= 3 }
        ) {
            callCount += 1
            return callCount
        }
        #expect(result == 3)
        #expect(callCount == 3)
    }

    @Test func runUntil_returnsLastResultWhenNeverSucceeds() async {
        var callCount = 0
        let result = await AsyncRetry.runUntil(
            maxAttempts: 3,
            isSuccess: { _ in false }
        ) {
            callCount += 1
            return callCount
        }
        #expect(result == 3)
        #expect(callCount == 3)
    }
}
