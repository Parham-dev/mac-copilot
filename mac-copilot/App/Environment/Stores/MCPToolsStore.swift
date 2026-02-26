import Foundation
import Combine

@MainActor
final class MCPToolsStore: ObservableObject {
    private let preferencesStore: MCPToolsPreferencesStoring
    @Published private(set) var changeToken: Int = 0

    init(preferencesStore: MCPToolsPreferencesStoring) {
        self.preferencesStore = preferencesStore
    }

    func enabledToolIDs() -> [String] {
        let raw = preferencesStore.readEnabledMCPToolIDs()
        return Self.normalize(raw)
    }

    func setEnabledToolIDs(_ ids: [String]) {
        let normalized = Self.normalize(ids)
        preferencesStore.writeEnabledMCPToolIDs(normalized)
        changeToken += 1
    }

    private static func normalize(_ ids: [String]) -> [String] {
        let trimmed = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(trimmed)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
