import Foundation

struct CopilotModelCatalogItem: Identifiable, Hashable {
    let id: String
    let name: String
    let maxContextWindowTokens: Int?
    let maxPromptTokens: Int?
    let supportsVision: Bool
    let supportsReasoningEffort: Bool
    let policyState: String?
    let policyTerms: String?
    let billingMultiplier: Double?
    let supportedReasoningEfforts: [String]
    let defaultReasoningEffort: String?
}

final class CopilotAPIService {
    private let baseURL = URL(string: "http://127.0.0.1:7878")!

    struct PromptStreamError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    private struct SSEPayload: Decodable {
        let type: String?
        let text: String?
        let label: String?
        let toolName: String?
        let success: Bool?
        let details: String?
        let error: String?
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

    func fetchModels() async -> [String] {
        let catalog = await fetchModelCatalog()
        let ids = catalog.map(\ .id)
        return ids.isEmpty ? ["gpt-5"] : ids
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

    func streamPrompt(_ prompt: String, model: String?, projectPath: String?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    NSLog("[CopilotForge][Prompt] stream start (chars=%d)", prompt.count)
                    var request = URLRequest(url: baseURL.appendingPathComponent("prompt"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode([
                        "prompt": prompt,
                        "model": model ?? "gpt-5",
                        "projectPath": projectPath ?? "",
                    ])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw PromptStreamError(message: "Invalid sidecar response")
                    }

                    guard (200 ... 299).contains(http.statusCode) else {
                        throw PromptStreamError(message: "Sidecar HTTP \(http.statusCode)")
                    }

                    NSLog("[CopilotForge][Prompt] stream connected (HTTP %d)", http.statusCode)

                    var receivedChunks = 0
                    var receivedChars = 0

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }

                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" {
                            NSLog("[CopilotForge][Prompt] stream done (chunks=%d chars=%d)", receivedChunks, receivedChars)
                            break
                        }

                        guard let data = payload.data(using: .utf8) else { continue }
                        let decoded = try JSONDecoder().decode(SSEPayload.self, from: data)

                        if let error = decoded.error {
                            throw PromptStreamError(message: error)
                        }

                        if let kind = decoded.type {
                            switch kind {
                            case "status":
                                if let label = decoded.label, !label.isEmpty {
                                    continuation.yield(.status(label))
                                }
                            case "tool_start":
                                if let name = decoded.toolName, !name.isEmpty {
                                    continuation.yield(.status("Tool started: \(name)"))
                                }
                            case "tool_complete":
                                if let name = decoded.toolName, !name.isEmpty {
                                    let suffix = (decoded.success == false) ? "failed" : "done"
                                    continuation.yield(.status("Tool \(suffix): \(name)"))
                                    continuation.yield(
                                        .toolExecution(
                                            PromptToolExecutionEvent(
                                                toolName: name,
                                                success: decoded.success != false,
                                                details: decoded.details
                                            )
                                        )
                                    )
                                }
                            case "done":
                                continuation.yield(.completed)
                            default:
                                break
                            }
                        }

                        if let text = decoded.text, !text.isEmpty {
                            receivedChunks += 1
                            receivedChars += text.count
                            continuation.yield(.textDelta(text))
                        }
                    }

                    continuation.finish()
                } catch {
                    NSLog("[CopilotForge][Prompt] stream error: %@", error.localizedDescription)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
