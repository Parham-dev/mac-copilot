import Foundation

enum ModelsManagementSheetSupport {
    static func formatInteger(_ value: Int?) -> String {
        guard let value, value > 0 else { return "Unknown" }
        return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    static func formatMultiplier(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return String(format: "%.2fx", value)
    }

    static func needsEnableAction(_ model: CopilotModelCatalogItem) -> Bool {
        guard let state = model.policyState?.lowercased() else { return false }
        return state != "enabled"
    }

    static func enableURL(for model: CopilotModelCatalogItem) -> URL? {
        if let terms = model.policyTerms,
           let termsURL = URL(string: terms),
           let scheme = termsURL.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            return termsURL
        }

        return URL(string: "https://github.com/settings/copilot")
    }
}
