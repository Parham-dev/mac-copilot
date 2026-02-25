import Foundation

struct PromptStreamError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class CopilotPromptStreamClient {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    NSLog("[CopilotForge][Prompt] stream start (chatID=%@ chars=%d)", chatID.uuidString, prompt.count)
                    var request = URLRequest(url: baseURL.appendingPathComponent("prompt"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    var payload: [String: Any] = [
                        "prompt": prompt,
                        "chatID": chatID.uuidString,
                        "model": model ?? "gpt-5",
                        "projectPath": projectPath ?? "",
                    ]

                    if let allowedTools {
                        payload["allowedTools"] = allowedTools
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await connectWithRetry(request: request)
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
    func connectWithRetry(request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        do {
            return try await URLSession.shared.bytes(for: request)
        } catch {
            guard shouldRetryConnection(error) else {
                throw error
            }

            NSLog("[CopilotForge][Prompt] sidecar not ready, retrying connection once")
            try? await Task.sleep(nanoseconds: 450_000_000)
            return try await URLSession.shared.bytes(for: request)
        }
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
    let error: String?
}
