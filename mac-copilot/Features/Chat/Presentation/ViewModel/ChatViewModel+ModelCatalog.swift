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

        let fetched = await fetchModelDataWithRetry()
        let modelCatalog = fetched.catalog
        modelCatalogByID = Dictionary(uniqueKeysWithValues: modelCatalog.map { ($0.id, $0) })
        modelCatalogErrorMessage = fetched.errorMessage

        let models = fetched.models
        guard !models.isEmpty else {
            availableModels = []
            if !selectedModel.isEmpty {
                selectedModel = ""
            }
            return
        }

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

    private func fetchModelDataWithRetry(maxAttempts: Int = 3) async -> (catalog: [CopilotModelCatalogItem], models: [String], errorMessage: String?) {
        await AsyncRetry.runUntil(
            maxAttempts: maxAttempts,
            delayForAttempt: { _ in 0.5 },
            isSuccess: { !$0.models.isEmpty || $0.errorMessage != nil },
            operation: {
                do {
                    let catalog = try await fetchModelCatalogUseCase.execute()
                    let models = catalog.map(\.id)
                    return (catalog, models, nil)
                } catch {
                    let message = modelCatalogErrorMessage(for: error)
                    return ([], [], message)
                }
            }
        )
    }

    private func modelCatalogErrorMessage(for error: Error) -> String {
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
