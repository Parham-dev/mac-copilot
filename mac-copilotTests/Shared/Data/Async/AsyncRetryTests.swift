import Foundation
import Testing
@testable import mac_copilot

struct AsyncRetryTests {
    @Test(.tags(.unit, .async_)) func succeedsOnFirstAttempt() async throws {
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

    @Test(.tags(.unit, .async_)) func retriesAndSucceedsOnSecondAttempt() async throws {
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

    @Test(.tags(.unit, .async_)) func throwsAfterExhaustingMaxAttempts() async {
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

    @Test(.tags(.unit, .async_)) func stopsRetryingWhenShouldRetryReturnsFalse() async {
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

    @Test(.tags(.unit, .async_)) func callsOnRetryCallback() async throws {
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

    @Test(.tags(.unit, .async_)) func delayForAttempt_isInvokedWithCorrectAttemptNumbers() async {
        var recordedAttempts: [Int] = []
        _ = try? await AsyncRetry.run(
            maxAttempts: 3,
            delayForAttempt: { attempt in recordedAttempts.append(attempt); return 0 },
            shouldRetry: { _, _ in true }
        ) {
            throw URLError(.cannotConnectToHost)
        } as Int
        #expect(recordedAttempts == [1, 2])
    }

    @Test(.tags(.unit, .async_)) func runUntil_returnsResultOnFirstSuccess() async {
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

    @Test(.tags(.unit, .async_)) func runUntil_retriesUntilSuccessConditionMet() async {
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

    @Test(.tags(.unit, .async_)) func runUntil_returnsLastResultWhenNeverSucceeds() async {
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
