import Foundation

@MainActor
protocol AppUpdateManaging {
    func checkForUpdates() throws
}

enum AppUpdateError: LocalizedError {
    case notConfigured
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "App updates are not configured yet. Missing SUFeedURL or SUPublicEDKey."
        case .unavailable:
            return "Update service is currently unavailable."
        }
    }
}
