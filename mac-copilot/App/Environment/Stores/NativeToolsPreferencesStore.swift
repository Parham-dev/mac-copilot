import Foundation

protocol NativeToolsPreferencesStoring {
    func readEnabledNativeToolIDs() -> [String]
    func writeEnabledNativeToolIDs(_ ids: [String])
}

final class UserDefaultsNativeToolsPreferencesStore: NativeToolsPreferencesStoring {
    private let nativeKey: String
    private let legacyKey: String
    private let defaults: UserDefaults

    init(
        nativeKey: String = "copilotforge.enabledNativeToolIDs",
        legacyKey: String = "copilotforge.enabledMCPToolIDs",
        defaults: UserDefaults = .standard
    ) {
        self.nativeKey = nativeKey
        self.legacyKey = legacyKey
        self.defaults = defaults
    }

    func readEnabledNativeToolIDs() -> [String] {
        if let current = defaults.stringArray(forKey: nativeKey) {
            return current
        }

        let legacy = defaults.stringArray(forKey: legacyKey) ?? []
        if !legacy.isEmpty {
            defaults.set(legacy, forKey: nativeKey)
        }
        return legacy
    }

    func writeEnabledNativeToolIDs(_ ids: [String]) {
        defaults.set(ids, forKey: nativeKey)
    }
}
