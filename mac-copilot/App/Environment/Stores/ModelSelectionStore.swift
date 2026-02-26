import Foundation
import Combine

@MainActor
final class ModelSelectionStore: ObservableObject {
    private let preferencesStore: ModelSelectionPreferencesStoring
    @Published private(set) var changeToken: Int = 0

    init(preferencesStore: ModelSelectionPreferencesStoring) {
        self.preferencesStore = preferencesStore
    }

    func selectedModelIDs() -> [String] {
        let raw = preferencesStore.readSelectedModelIDs()
        return NormalizedIDList.from(raw)
    }

    func setSelectedModelIDs(_ ids: [String]) {
        let normalized = NormalizedIDList.from(ids)
        preferencesStore.writeSelectedModelIDs(normalized)
        changeToken += 1
    }
}
