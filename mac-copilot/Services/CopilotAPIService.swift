import Foundation

final class CopilotAPIService {
    private let baseURL = URL(string: "http://localhost:7878")!

    struct PromptStreamError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    private struct SSEPayload: Decodable {
        let text: String?
        let error: String?
    }

    func streamPrompt(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    NSLog("[CopilotForge][Prompt] stream start (chars=%d)", prompt.count)
                    var request = URLRequest(url: baseURL.appendingPathComponent("prompt"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(["prompt": prompt])

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

                        if let text = decoded.text, !text.isEmpty {
                            receivedChunks += 1
                            receivedChars += text.count
                            continuation.yield(text)
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
