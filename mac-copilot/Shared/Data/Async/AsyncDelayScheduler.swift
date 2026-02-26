import Foundation

protocol AsyncDelayScheduling {
    func sleep(seconds: TimeInterval) async throws
}

struct TaskAsyncDelayScheduler: AsyncDelayScheduling {
    func sleep(seconds: TimeInterval) async throws {
        let clamped = max(0, seconds)
        let nanos = UInt64(clamped * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanos)
    }
}
