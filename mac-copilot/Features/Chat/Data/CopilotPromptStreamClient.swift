import Foundation

struct PromptStreamError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class CopilotPromptStreamClient {
    private let baseURL: URL
    private let ensureSidecarRunning: () -> Void
    private let lineStreamTransport: HTTPLineStreamTransporting
    private let delayScheduler: AsyncDelayScheduling

    init(
        baseURL: URL,
        ensureSidecarRunning: @escaping () -> Void = {},
        lineStreamTransport: HTTPLineStreamTransporting = URLSessionHTTPLineStreamTransport(),
        delayScheduler: AsyncDelayScheduling = TaskAsyncDelayScheduler()
    ) {
        self.baseURL = baseURL
        self.ensureSidecarRunning = ensureSidecarRunning
        self.lineStreamTransport = lineStreamTransport
        self.delayScheduler = delayScheduler
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    ensureSidecarRunning()
                    NSLog("[CopilotForge][Prompt] stream start (chatID=%@ chars=%d)", chatID.uuidString, prompt.count)
                    var request = URLRequest(url: baseURL.appendingPathComponent("prompt"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    var payload: [String: Any] = [
                        "prompt": prompt,
                        "chatID": chatID.uuidString,
                        "projectPath": projectPath ?? "",
                    ]

                    if let model, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        payload["model"] = model
                    }

                    if let allowedTools {
                        payload["allowedTools"] = allowedTools
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let stream = try await connectWithRetry(request: request)
                    let response = stream.response
                    guard let http = response as? HTTPURLResponse else {
                        throw PromptStreamError(message: "Invalid sidecar response")
                    }

                    guard (200 ... 299).contains(http.statusCode) else {
                        throw PromptStreamError(message: "Sidecar HTTP \(http.statusCode)")
                    }

                    NSLog("[CopilotForge][Prompt] stream connected (HTTP %d)", http.statusCode)

                    var receivedChunks = 0
                    var receivedChars = 0
                    var protocolMarkerChunkCount = 0

                    for try await line in stream.lines {
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
                                                details: decoded.details,
                                                input: decoded.toolInput,
                                                output: decoded.toolOutput ?? decoded.details
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

                            if PromptTrace.containsProtocolMarker(in: text) {
                                protocolMarkerChunkCount += 1
                                NSLog(
                                    "[CopilotForge][PromptTrace] decoded text contains protocol marker (chatID=%@ chunk=%d chars=%d preview=%@)",
                                    chatID.uuidString,
                                    receivedChunks,
                                    text.count,
                                    String(text.prefix(180))
                                )
                            }

                            continuation.yield(.textDelta(text))
                        }
                    }

                    if PromptTrace.isEnabled {
                        NSLog(
                            "[CopilotForge][PromptTrace] stream summary (chatID=%@ chunks=%d chars=%d protocolChunks=%d)",
                            chatID.uuidString,
                            receivedChunks,
                            receivedChars,
                            protocolMarkerChunkCount
                        )
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

private extension CopilotPromptStreamClient {
    func connectWithRetry(request: URLRequest) async throws -> HTTPLineStreamResponse {
        let requestPath = request.url?.path ?? "<unknown>"

        for attempt in 1 ... 5 {
            do {
                return try await lineStreamTransport.openLineStream(for: request)
            } catch {
                let recoverable = shouldRetryConnection(error)

                guard recoverable, attempt < 5 else {
                    NSLog(
                        "[CopilotForge][Prompt] stream connect failed path=%@ attempts=%d recoverable=%@ error=%@",
                        requestPath,
                        attempt,
                        recoverable ? "true" : "false",
                        error.localizedDescription
                    )
                    throw error
                }

                ensureSidecarRunning()

                let delay = min(0.25 * Double(attempt), 1.0)
                try? await delayScheduler.sleep(seconds: delay)
            }
        }

        throw PromptStreamError(message: "Unable to establish stream")
    }

    func shouldRetryConnection(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain != NSURLErrorDomain {
            return false
        }

        return nsError.code == NSURLErrorCannotConnectToHost
            || nsError.code == NSURLErrorNetworkConnectionLost
            || nsError.code == NSURLErrorTimedOut
    }
}

private struct SSEPayload: Decodable {
    let type: String?
    let text: String?
    let label: String?
    let toolName: String?
    let success: Bool?
    let details: String?
    let toolInput: String?
    let toolOutput: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case label
        case toolName
        case success
        case details
        case input
        case output
        case arguments
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        details = try container.decodeFlexibleString(forKey: .details)
        toolInput = try container.decodeFlexibleString(forKey: .input)
            ?? container.decodeFlexibleString(forKey: .arguments)
        toolOutput = try container.decodeFlexibleString(forKey: .output)
            ?? container.decodeFlexibleString(forKey: .result)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }

        if let jsonValue = try decodeIfPresent(SSEJSONValue.self, forKey: key) {
            return jsonValue.rendered
        }

        return nil
    }
}

private enum SSEJSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: SSEJSONValue])
    case array([SSEJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: SSEJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([SSEJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                SSEJSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }

    var rendered: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.formatted(.number)
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array:
            guard let data = try? JSONSerialization.data(withJSONObject: foundationObject, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return text
        case .null:
            return ""
        }
    }

    private var foundationObject: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let dictionary):
            return dictionary.mapValues { $0.foundationObject }
        case .array(let values):
            return values.map { $0.foundationObject }
        case .null:
            return NSNull()
        }
    }
}
