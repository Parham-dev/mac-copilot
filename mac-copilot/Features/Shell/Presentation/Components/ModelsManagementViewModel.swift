import Foundation
import Combine

@MainActor
final class ModelsManagementViewModel: ObservableObject {
    @Published private(set) var models: [CopilotModelCatalogItem] = []
    @Published var selectedModelIDs: Set<String> = []
    @Published var focusedModelID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = CopilotAPIService()
    private let modelSelectionStore: ModelSelectionStore

    init(modelSelectionStore: ModelSelectionStore) {
        self.modelSelectionStore = modelSelectionStore
    }

    var focusedModel: CopilotModelCatalogItem? {
        guard let focusedModelID else { return models.first }
        return models.first(where: { $0.id == focusedModelID })
    }

    func loadModels() async {
        guard models.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        let fetched = await apiService.fetchModelCatalog()
        models = fetched

        let persisted = Set(modelSelectionStore.selectedModelIDs())
        if persisted.isEmpty {
            selectedModelIDs = Set(fetched.map(\.id))
        } else {
            let visible = Set(fetched.map(\.id).filter { persisted.contains($0) })
            selectedModelIDs = visible.isEmpty ? Set(fetched.map(\.id)) : visible
        }

        if focusedModelID == nil {
            focusedModelID = fetched.first?.id
        }

        isLoading = false
        if fetched.isEmpty {
            errorMessage = "No models are currently available."
        }
    }

    func selectAll() {
        selectedModelIDs = Set(models.map(\.id))
    }

    func clearSelection() {
        selectedModelIDs.removeAll()
    }

    func setModel(_ modelID: String, isSelected: Bool) {
        if isSelected {
            selectedModelIDs.insert(modelID)
        } else {
            selectedModelIDs.remove(modelID)
        }
    }

    func saveSelection() {
        modelSelectionStore.setSelectedModelIDs(Array(selectedModelIDs))
    }
}
