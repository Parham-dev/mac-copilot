import Foundation

enum AsyncRetry {
    static func run<T>(
        maxAttempts: Int,
        delayForAttempt: (Int) -> TimeInterval = { _ in 0 },
        shouldRetry: (Error, Int) -> Bool,
        onRetry: ((Error, Int) async throws -> Void)? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        precondition(maxAttempts > 0, "maxAttempts must be greater than zero")

        var lastError: Error?

        for attempt in 1 ... maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                guard attempt < maxAttempts, shouldRetry(error, attempt) else {
                    throw error
                }

                if let onRetry {
                    try await onRetry(error, attempt)
                }

                let delay = max(0, delayForAttempt(attempt))
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? RetryError.exhausted
    }

    static func runUntil<T>(
        maxAttempts: Int,
        delayForAttempt: (Int) -> TimeInterval = { _ in 0 },
        isSuccess: (T) -> Bool,
        operation: () async -> T
    ) async -> T {
        precondition(maxAttempts > 0, "maxAttempts must be greater than zero")

        var latest = await operation()
        if isSuccess(latest) {
            return latest
        }

        guard maxAttempts > 1 else {
            return latest
        }

        for attempt in 2 ... maxAttempts {
            let delay = max(0, delayForAttempt(attempt - 1))
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            latest = await operation()
            if isSuccess(latest) {
                return latest
            }
        }

        return latest
    }
}

private enum RetryError: Error {
    case exhausted
}
