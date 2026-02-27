import Foundation
import Sparkle

@MainActor
final class SparkleAppUpdateManager: AppUpdateManaging {
    private let updaterController: SPUStandardUpdaterController
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() throws {
        guard isConfigured else {
            throw AppUpdateError.notConfigured
        }

        guard updaterController.updater.canCheckForUpdates else {
            throw AppUpdateError.unavailable
        }

        updaterController.checkForUpdates(nil)
    }

    private var isConfigured: Bool {
        let feedURL = (bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let publicEDKey = (bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return !(feedURL?.isEmpty ?? true) && !(publicEDKey?.isEmpty ?? true)
    }
}
