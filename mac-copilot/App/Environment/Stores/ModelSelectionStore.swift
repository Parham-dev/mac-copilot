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
        return Self.normalize(raw)
    }

    func setSelectedModelIDs(_ ids: [String]) {
        let normalized = Self.normalize(ids)
        preferencesStore.writeSelectedModelIDs(normalized)
        changeToken += 1
    }

    private static func normalize(_ ids: [String]) -> [String] {
        let trimmed = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(trimmed)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
