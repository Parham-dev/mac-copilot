import Foundation

protocol ModelSelectionPreferencesStoring {
    func readSelectedModelIDs() -> [String]
    func writeSelectedModelIDs(_ ids: [String])
}

final class UserDefaultsModelSelectionPreferencesStore: ModelSelectionPreferencesStoring {
    private let key: String
    private let defaults: UserDefaults

    init(key: String = "copilotforge.selectedModelIDs", defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    func readSelectedModelIDs() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func writeSelectedModelIDs(_ ids: [String]) {
        defaults.set(ids, forKey: key)
    }
}
