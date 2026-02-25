import Foundation

extension ChatViewModel {
    var selectedModelInfoLabel: String {
        guard let model = modelCatalogByID[selectedModel] else {
            return "Stats unavailable"
        }

        var parts: [String] = []
        if let multiplier = model.billingMultiplier {
            parts.append(String(format: "x%.2f", multiplier))
        }
        if let maxPromptTokens = model.maxPromptTokens, maxPromptTokens > 0 {
            parts.append("In \(compactTokenString(maxPromptTokens))")
        }
        if let maxContextWindowTokens = model.maxContextWindowTokens, maxContextWindowTokens > 0 {
            parts.append("Ctx \(compactTokenString(maxContextWindowTokens))")
        }
        if model.supportsVision {
            parts.append("Vision")
        }
        if model.supportsReasoningEffort {
            parts.append("Reasoning")
        }

        return parts.isEmpty ? "Stats unavailable" : parts.joined(separator: " • ")
    }

    func loadModelsIfNeeded(forceReload: Bool = false) async {
        if !forceReload, availableModels.count > 1 {
            return
        }

        let modelCatalog = await fetchModelCatalogUseCase.execute()
        modelCatalogByID = Dictionary(uniqueKeysWithValues: modelCatalog.map { ($0.id, $0) })

        let models = await fetchModelsUseCase.execute()
        if !models.isEmpty {
            let preferredVisible = Set(modelSelectionStore.selectedModelIDs())
            let filtered: [String]

            if preferredVisible.isEmpty {
                filtered = models
            } else {
                let matches = models.filter { preferredVisible.contains($0) }
                filtered = matches.isEmpty ? models : matches
            }

            availableModels = filtered
            if !filtered.contains(selectedModel), let first = filtered.first {
                selectedModel = first
            }
        }
    }

    private func compactTokenString(_ value: Int) -> String {
        if value >= 1_000_000 {
            return "\(value / 1_000_000)M"
        }
        if value >= 1_000 {
            return "\(value / 1_000)K"
        }
        return String(value)
    }
}
