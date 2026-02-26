import Foundation
import Sentry

enum SentryMonitoring {
    private static let duplicateWindowSeconds: TimeInterval = 60
    private static let lock = NSLock()

    private static var started = false
    private static var recentEventTimestamps: [String: Date] = [:]

    static func start() {
        guard let dsn, !dsn.isEmpty else {
            NSLog("[CopilotForge][Monitoring] Sentry disabled: SENTRY_DSN is not configured")
            return
        }

        lock.lock()
        let shouldStart = !started
        if shouldStart {
            started = true
        }
        lock.unlock()

        guard shouldStart else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.sendDefaultPii = false
            options.maxBreadcrumbs = 25
            options.tracesSampleRate = 0
            options.enableLogs = true
            options.environment = buildEnvironment
            options.releaseName = appReleaseName
        }
    }

    static func captureError(
        _ error: Error,
        category: String,
        extras: [String: String] = [:],
        throttleKey: String? = nil
    ) {
        guard shouldCapture(category: category, throttleKey: throttleKey) else {
            return
        }

        SentrySDK.configureScope { scope in
            scope.setTag(value: category, key: "category")
            for (key, value) in extras {
                scope.setExtra(value: value, key: key)
            }
        }
        let eventID = SentrySDK.capture(error: error)
        _ = SentrySDK.flush(timeout: 2.0)
    }

    static func captureMessage(
        _ message: String,
        category: String,
        extras: [String: String] = [:],
        throttleKey: String? = nil
    ) {
        let info = extras.merging(["message": message]) { current, _ in current }
        let wrapped = NSError(domain: category, code: 1, userInfo: info)
        captureError(wrapped, category: category, extras: extras, throttleKey: throttleKey)
    }
}

private extension SentryMonitoring {
    static var dsn: String? {
        if let value = (Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        if let value = ProcessInfo.processInfo.environment["SENTRY_DSN"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        return nil
    }

    static var appReleaseName: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "mac-copilot@\(version)+\(build)"
    }

    static var buildEnvironment: String {
        if let value = ProcessInfo.processInfo.environment["APP_ENV"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        return "production"
    }

    static func shouldCapture(category: String, throttleKey: String?) -> Bool {
        guard let key = throttleKey, !key.isEmpty else {
            return true
        }

        let token = "\(category)|\(key)"
        let now = Date()

        lock.lock()
        defer { lock.unlock() }

        if let last = recentEventTimestamps[token], now.timeIntervalSince(last) < duplicateWindowSeconds {
            return false
        }

        recentEventTimestamps[token] = now
        pruneOldEntries(relativeTo: now)
        return true
    }

    static func pruneOldEntries(relativeTo now: Date) {
        guard recentEventTimestamps.count > 250 else {
            return
        }

        recentEventTimestamps = recentEventTimestamps.filter { _, timestamp in
            now.timeIntervalSince(timestamp) < 3600
        }
    }
}