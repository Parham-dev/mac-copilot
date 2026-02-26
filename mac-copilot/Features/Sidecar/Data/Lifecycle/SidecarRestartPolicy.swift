import Foundation

final class SidecarRestartPolicy {
    private let maxRestartsInWindow: Int
    private let restartWindowSeconds: TimeInterval
    private let maximumBackoffSeconds: Double
    private let jitterProvider: () -> Double

    private var restartTimestamps: [Date] = []
    private(set) var retryAttempt = 0

    init(
        maxRestartsInWindow: Int,
        restartWindowSeconds: TimeInterval,
        maximumBackoffSeconds: Double = 8,
        jitterProvider: @escaping () -> Double = { Double.random(in: 0.0 ... 0.4) }
    ) {
        self.maxRestartsInWindow = maxRestartsInWindow
        self.restartWindowSeconds = restartWindowSeconds
        self.maximumBackoffSeconds = maximumBackoffSeconds
        self.jitterProvider = jitterProvider
    }

    func canAttemptRestart(now: Date) -> Bool {
        restartTimestamps = restartTimestamps.filter { now.timeIntervalSince($0) <= restartWindowSeconds }
        if restartTimestamps.count >= maxRestartsInWindow {
            return false
        }
        restartTimestamps.append(now)
        return true
    }

    func resetRetryAttempt() {
        retryAttempt = 0
    }

    func nextRetryDelay() -> TimeInterval {
        retryAttempt += 1
        let base = min(pow(2.0, Double(retryAttempt)), maximumBackoffSeconds)
        let jitter = min(max(jitterProvider(), 0.0), 0.4)
        return base + jitter
    }
}
