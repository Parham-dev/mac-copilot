import Foundation
import Combine

@MainActor
final class NativeToolsStore: ObservableObject {
    private let preferencesStore: NativeToolsPreferencesStoring
    @Published private(set) var changeToken: Int = 0

    init(preferencesStore: NativeToolsPreferencesStoring) {
        self.preferencesStore = preferencesStore
    }

    func enabledNativeToolIDs() -> [String] {
        let raw = preferencesStore.readEnabledNativeToolIDs()
        return NormalizedIDList.from(raw)
    }

    func setEnabledNativeToolIDs(_ ids: [String]) {
        let normalized = NormalizedIDList.from(ids)
        preferencesStore.writeEnabledNativeToolIDs(normalized)
        changeToken += 1
    }
}
