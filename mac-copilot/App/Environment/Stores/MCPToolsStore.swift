import Foundation
import Combine

@MainActor
final class MCPToolsStore: ObservableObject {
    private let preferencesStore: MCPToolsPreferencesStoring
    @Published private(set) var changeToken: Int = 0

    init(preferencesStore: MCPToolsPreferencesStoring) {
        self.preferencesStore = preferencesStore
    }

    func enabledMCPToolIDs() -> [String] {
        let raw = preferencesStore.readEnabledMCPToolIDs()
        return NormalizedIDList.from(raw)
    }

    func setEnabledMCPToolIDs(_ ids: [String]) {
        let normalized = NormalizedIDList.from(ids)
        preferencesStore.writeEnabledMCPToolIDs(normalized)
        changeToken += 1
    }
}
