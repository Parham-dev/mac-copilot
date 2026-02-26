import Foundation

final class CopilotModelCatalogClient {
    private let baseURL: URL
    private let ensureSidecarRunning: () -> Void
    private let transport: HTTPDataTransporting
    private let delayScheduler: AsyncDelayScheduling

    init(
        baseURL: URL,
        ensureSidecarRunning: @escaping () -> Void = {},
        transport: HTTPDataTransporting? = nil,
        delayScheduler: AsyncDelayScheduling? = nil
    ) {
        self.baseURL = baseURL
        self.ensureSidecarRunning = ensureSidecarRunning
        self.transport = transport ?? URLSessionHTTPDataTransport()
        self.delayScheduler = delayScheduler ?? TaskAsyncDelayScheduler()
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        ensureSidecarRunning()

        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        do {
            let (data, response) = try await fetchDataWithConnectionRetry(request: request)
            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode)
            else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                NSLog("[CopilotForge][Models] fetch failed with HTTP status=\(status)")
                SentryMonitoring.captureMessage(
                    "Model catalog request returned non-success status",
                    category: "model_catalog",
                    extras: ["statusCode": String(status)],
                    throttleKey: "http_\(status)"
                )
                return []
            }

            let payloads = try decodeModelPayloads(from: data)
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

            let unique = uniqueByID.values.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
            if unique.isEmpty {
                NSLog("[CopilotForge][Models] decoded catalog is empty")
            }
            return unique
        } catch {
            NSLog("[CopilotForge][Models] fetch/decode failed: \(error.localizedDescription)")
            SentryMonitoring.captureError(
                error,
                category: "model_catalog",
                throttleKey: "fetch_or_decode"
            )
            return []
        }
    }

    private func fetchDataWithConnectionRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await transport.data(for: request)
        } catch {
            guard shouldRetryConnection(error) else {
                throw error
            }

            ensureSidecarRunning()
            try? await delayScheduler.sleep(seconds: 0.45)
            return try await transport.data(for: request)
        }
    }

    private func shouldRetryConnection(_ error: Error) -> Bool {
        RecoverableNetworkError.isConnectionRelated(error)
    }

    private func decodeModelPayloads(from data: Data) throws -> [ModelPayload] {
        let decoder = JSONDecoder()

        if let wrapped = try? decoder.decode(ModelsResponse.self, from: data) {
            return wrapped.models
        }

        if let wrappedStrings = try? decoder.decode(ModelsStringResponse.self, from: data) {
            return wrappedStrings.models.map { ModelPayload(stringID: $0) }
        }

        if let direct = try? decoder.decode([ModelPayload].self, from: data) {
            return direct
        }

        if let directStrings = try? decoder.decode([String].self, from: data) {
            return directStrings.map { ModelPayload(stringID: $0) }
        }

        throw ModelsDecodeError.unsupportedShape
    }
}

private struct ModelsResponse: Decodable {
    let ok: Bool?
    let models: [ModelPayload]
}

private struct ModelsStringResponse: Decodable {
    let ok: Bool?
    let models: [String]
}

private enum ModelsDecodeError: Error {
    case unsupportedShape
}

private struct ModelPayload: Decodable {
    let id: String
    let name: String?
    let capabilities: ModelCapabilitiesPayload?
    let policy: ModelPolicyPayload?
    let billing: ModelBillingPayload?
    let supportedReasoningEfforts: [String]?
    let defaultReasoningEffort: String?

    init(stringID: String) {
        self.id = stringID
        self.name = stringID
        self.capabilities = nil
        self.policy = nil
        self.billing = nil
        self.supportedReasoningEfforts = nil
        self.defaultReasoningEffort = nil
    }

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
        self.id = object.id ?? object.model ?? ""
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.maxPromptTokens = Self.decodeInt(container: container, key: .maxPromptTokens)
        self.maxContextWindowTokens = Self.decodeInt(container: container, key: .maxContextWindowTokens)
    }

    private static func decodeInt(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try? container.decode(String.self, forKey: key),
           let intValue = Int(stringValue) {
            return intValue
        }

        return nil
    }
}

private struct ModelPolicyPayload: Decodable {
    let state: String?
    let terms: String?
}

private struct ModelBillingPayload: Decodable {
    let multiplier: Double?
}
