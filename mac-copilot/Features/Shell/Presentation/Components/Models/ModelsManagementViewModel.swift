import Foundation
import Combine

@MainActor
final class ModelsManagementViewModel: ObservableObject {
    @Published private(set) var models: [CopilotModelCatalogItem] = []
    @Published var selectedModelIDs: Set<String> = []
    @Published var focusedModelID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let modelSelectionStore: ModelSelectionStore
    private let modelRepository: ModelListingRepository

    init(modelSelectionStore: ModelSelectionStore, modelRepository: ModelListingRepository) {
        self.modelSelectionStore = modelSelectionStore
        self.modelRepository = modelRepository
    }

    var focusedModel: CopilotModelCatalogItem? {
        guard let focusedModelID else { return models.first }
        return models.first(where: { $0.id == focusedModelID })
    }

    func loadModels() async {
        guard models.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await modelRepository.fetchModelCatalog()
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

            if fetched.isEmpty {
                errorMessage = "No models are currently available."
            }
        } catch {
            models = []
            selectedModelIDs = []
            focusedModelID = nil
            errorMessage = mapCatalogLoadError(error)
        }
    }

    private func mapCatalogLoadError(_ error: Error) -> String {
        if let catalogError = error as? CopilotModelCatalogError {
            switch catalogError {
            case .notAuthenticated:
                return "Sign in to GitHub to load models."
            case .sidecarUnavailable:
                return "Local sidecar is offline. Relaunch app to retry."
            case .server:
                return catalogError.localizedDescription ?? "Model catalog request failed."
            case .invalidPayload:
                return "Model catalog response was invalid."
            }
        }

        return error.localizedDescription.isEmpty
            ? "Could not load models right now."
            : error.localizedDescription
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
