import Foundation

protocol MCPToolsPreferencesStoring {
    func readEnabledMCPToolIDs() -> [String]
    func writeEnabledMCPToolIDs(_ ids: [String])
}

final class UserDefaultsMCPToolsPreferencesStore: MCPToolsPreferencesStoring {
    private let key: String
    private let defaults: UserDefaults

    init(key: String = "copilotforge.enabledMCPToolIDs", defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    func readEnabledMCPToolIDs() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func writeEnabledMCPToolIDs(_ ids: [String]) {
        defaults.set(ids, forKey: key)
    }
}
