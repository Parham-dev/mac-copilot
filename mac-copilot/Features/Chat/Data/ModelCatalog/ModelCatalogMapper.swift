import Foundation

enum ModelCatalogMapper {
    static func mapToUniqueSortedItems(_ payloads: [ModelPayload]) -> [CopilotModelCatalogItem] {
        let mapped = payloads.map { payload in
            CopilotModelCatalogItem(
                id: payload.id,
                name: payload.name ?? payload.id,
                maxContextWindowTokens: payload.capabilities?.limits?.maxContextWindowTokens,
                maxPromptTokens: payload.capabilities?.limits?.maxPromptTokens,
                supportsVision: payload.capabilities?.supports?.vision ?? false,
                supportsReasoningEffort: payload.capabilities?.supports?.reasoningEffort ?? false,
                policyState: payload.policy?.state,
                policyTerms: payload.policy?.terms,
                billingMultiplier: payload.billing?.multiplier,
                supportedReasoningEfforts: payload.supportedReasoningEfforts ?? [],
                defaultReasoningEffort: payload.defaultReasoningEffort
            )
        }

        var uniqueByID: [String: CopilotModelCatalogItem] = [:]
        for item in mapped where !item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            uniqueByID[item.id] = item
        }

        return uniqueByID.values.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }
}