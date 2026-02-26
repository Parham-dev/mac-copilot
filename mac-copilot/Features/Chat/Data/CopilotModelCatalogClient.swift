import Foundation

enum CopilotModelCatalogError: LocalizedError {
    case sidecarUnavailable
    case notAuthenticated
    case server(statusCode: Int, message: String?)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .sidecarUnavailable:
            return "Could not connect to the local sidecar."
        case .notAuthenticated:
            return "Sign in to GitHub to load Copilot models."
        case .server(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Model catalog request failed (HTTP \(statusCode)): \(message)"
            }
            return "Model catalog request failed (HTTP \(statusCode))."
        case .invalidPayload:
            return "Model catalog response had an unsupported format."
        }
    }
}

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

    func fetchModelCatalog() async throws -> [CopilotModelCatalogItem] {
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
                let message = ModelCatalogDecoder.decodeErrorMessage(from: data)
                NSLog("[CopilotForge][Models] fetch failed with HTTP status=\(status)")
                SentryMonitoring.captureMessage(
                    "Model catalog request returned non-success status",
                    category: "model_catalog",
                    extras: [
                        "statusCode": String(status),
                        "message": message ?? ""
                    ],
                    throttleKey: "http_\(status)"
                )

                if status == 401 {
                    throw CopilotModelCatalogError.notAuthenticated
                }

                throw CopilotModelCatalogError.server(statusCode: status, message: message)
            }

            let payloads = try ModelCatalogDecoder.decodeModelPayloads(from: data)
            let unique = ModelCatalogMapper.mapToUniqueSortedItems(payloads)
            if unique.isEmpty {
                NSLog("[CopilotForge][Models] decoded catalog is empty")
            }
            return unique
        } catch let error as CopilotModelCatalogError {
            throw error
        } catch {
            NSLog("[CopilotForge][Models] fetch/decode failed: \(error.localizedDescription)")
            SentryMonitoring.captureError(
                error,
                category: "model_catalog",
                throttleKey: "fetch_or_decode"
            )

            if shouldRetryConnection(error) {
                throw CopilotModelCatalogError.sidecarUnavailable
            }

            if error is ModelsDecodeError {
                throw CopilotModelCatalogError.invalidPayload
            }

            throw error
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
}

struct ModelPayload: Decodable {
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

struct ModelObjectPayload: Decodable {
    let id: String?
    let model: String?
    let name: String?
    let capabilities: ModelCapabilitiesPayload?
    let policy: ModelPolicyPayload?
    let billing: ModelBillingPayload?
    let supportedReasoningEfforts: [String]?
    let defaultReasoningEffort: String?
}

struct ModelCapabilitiesPayload: Decodable {
    let supports: ModelSupportsPayload?
    let limits: ModelLimitsPayload?
}

struct ModelSupportsPayload: Decodable {
    let vision: Bool?
    let reasoningEffort: Bool?
}

struct ModelLimitsPayload: Decodable {
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

struct ModelPolicyPayload: Decodable {
    let state: String?
    let terms: String?
}

struct ModelBillingPayload: Decodable {
    let multiplier: Double?
}
