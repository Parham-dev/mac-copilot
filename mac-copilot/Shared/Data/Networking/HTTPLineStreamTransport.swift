import Foundation

struct HTTPLineStreamResponse {
    let lines: AsyncThrowingStream<String, Error>
    let response: URLResponse
}

protocol HTTPLineStreamTransporting {
    func openLineStream(for request: URLRequest) async throws -> HTTPLineStreamResponse
}

struct URLSessionHTTPLineStreamTransport: HTTPLineStreamTransporting {
    func openLineStream(for request: URLRequest) async throws -> HTTPLineStreamResponse {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        let lineStream = AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        return HTTPLineStreamResponse(lines: lineStream, response: response)
    }
}
