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
        lineStreamTransport: HTTPLineStreamTransporting? = nil,
        delayScheduler: AsyncDelayScheduling? = nil
    ) {
        self.baseURL = baseURL
        self.ensureSidecarRunning = ensureSidecarRunning
        self.lineStreamTransport = lineStreamTransport ?? URLSessionHTTPLineStreamTransport()
        self.delayScheduler = delayScheduler ?? TaskAsyncDelayScheduler()
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    ensureSidecarRunning()
                    NSLog("[CopilotForge][Prompt] stream start (chatID=%@ chars=%d)", chatID.uuidString, prompt.count)
                    let request = try PromptStreamRequestBuilder.makeRequest(
                        baseURL: baseURL,
                        prompt: prompt,
                        chatID: chatID,
                        model: model,
                        projectPath: projectPath,
                        allowedTools: allowedTools
                    )

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
                        guard let parsed = try PromptSSEDecoder.decode(line: line) else {
                            continue
                        }

                        if case .done = parsed {
                            NSLog("[CopilotForge][Prompt] stream done (chunks=%d chars=%d)", receivedChunks, receivedChars)
                            break
                        }

                        guard case .payload(let decoded) = parsed else {
                            continue
                        }

                        if let error = decoded.error {
                            throw PromptStreamError(message: error)
                        }

                        for event in PromptSSEEventMapper.events(from: decoded) {
                            continuation.yield(event)
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
        let maxAttempts = 5

        do {
            return try await AsyncRetry.run(
                maxAttempts: maxAttempts,
                delayForAttempt: { attempt in
                    min(0.25 * Double(attempt), 1.0)
                },
                shouldRetry: { [self] error, _ in
                    shouldRetryConnection(error)
                },
                onRetry: { [self] _, _ in
                    ensureSidecarRunning()
                },
                operation: {
                    try await lineStreamTransport.openLineStream(for: request)
                }
            )
        } catch {
            let recoverable = shouldRetryConnection(error)
            NSLog(
                "[CopilotForge][Prompt] stream connect failed path=%@ attempts=%d recoverable=%@ error=%@",
                requestPath,
                maxAttempts,
                recoverable ? "true" : "false",
                error.localizedDescription
            )
            throw error
        }
    }

    func shouldRetryConnection(_ error: Error) -> Bool {
        RecoverableNetworkError.isConnectionRelated(error)
    }
}
