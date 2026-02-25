import Foundation

final class CopilotModelCatalogClient {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode)
            else {
                return [fallbackModelItem]
            }

            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let mapped = decoded.models.map { payload in
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

            let unique = uniqueByID.values.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
            return unique.isEmpty ? [fallbackModelItem] : unique
        } catch {
            return [fallbackModelItem]
        }
    }

    private var fallbackModelItem: CopilotModelCatalogItem {
        CopilotModelCatalogItem(
            id: "gpt-5",
            name: "GPT-5",
            maxContextWindowTokens: nil,
            maxPromptTokens: nil,
            supportsVision: false,
            supportsReasoningEffort: false,
            policyState: nil,
            policyTerms: nil,
            billingMultiplier: nil,
            supportedReasoningEfforts: [],
            defaultReasoningEffort: nil
        )
    }
}

private struct ModelsResponse: Decodable {
    let ok: Bool
    let models: [ModelPayload]
}

private struct ModelPayload: Decodable {
    let id: String
    let name: String?
    let capabilities: ModelCapabilitiesPayload?
    let policy: ModelPolicyPayload?
    let billing: ModelBillingPayload?
    let supportedReasoningEfforts: [String]?
    let defaultReasoningEffort: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let id = try? container.decode(String.self) {
            self.id = id
            self.name = id
            self.capabilities = nil
            self.policy = nil
            self.billing = nil
            self.supportedReasoningEfforts = nil
            self.defaultReasoningEffort = nil
            return
        }

        let object = try container.decode(ModelObjectPayload.self)
        self.id = object.id ?? object.model ?? "gpt-5"
        self.name = object.name
        self.capabilities = object.capabilities
        self.policy = object.policy
        self.billing = object.billing
        self.supportedReasoningEfforts = object.supportedReasoningEfforts
        self.defaultReasoningEffort = object.defaultReasoningEffort
    }
}

private struct ModelObjectPayload: Decodable {
    let id: String?
    let model: String?
    let name: String?
    let capabilities: ModelCapabilitiesPayload?
    let policy: ModelPolicyPayload?
    let billing: ModelBillingPayload?
    let supportedReasoningEfforts: [String]?
    let defaultReasoningEffort: String?
}

private struct ModelCapabilitiesPayload: Decodable {
    let supports: ModelSupportsPayload?
    let limits: ModelLimitsPayload?
}

private struct ModelSupportsPayload: Decodable {
    let vision: Bool?
    let reasoningEffort: Bool?
}

private struct ModelLimitsPayload: Decodable {
    let maxPromptTokens: Int?
    let maxContextWindowTokens: Int?

    enum CodingKeys: String, CodingKey {
        case maxPromptTokens = "max_prompt_tokens"
        case maxContextWindowTokens = "max_context_window_tokens"
    }
}

private struct ModelPolicyPayload: Decodable {
    let state: String?
    let terms: String?
}

private struct ModelBillingPayload: Decodable {
    let multiplier: Double?
}
