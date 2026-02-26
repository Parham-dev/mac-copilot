import Foundation

protocol HTTPDataTransporting {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionHTTPDataTransport: HTTPDataTransporting {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}
