import Foundation

@MainActor
final class SidecarCompanionClient {
    private let transport: SidecarHTTPClient

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:7878")!,
        sidecarLifecycle: SidecarLifecycleManaging
    ) {
        self.transport = SidecarHTTPClient(baseURL: baseURL, sidecarLifecycle: sidecarLifecycle)
    }

    func fetchStatus() async throws -> SidecarCompanionStatusResponse {
        try await get(path: "companion/status", as: SidecarCompanionStatusResponse.self)
    }

    func startPairing() async throws -> SidecarCompanionPairingStartResponse {
        try await post(path: "companion/pairing/start", body: EmptyBody(), as: SidecarCompanionPairingStartResponse.self)
    }

    func disconnect() async throws -> SidecarCompanionStatusResponse {
        try await post(path: "companion/disconnect", body: EmptyBody(), as: SidecarCompanionStatusResponse.self)
    }

    private func get<ResponseBody: Decodable>(path: String, as type: ResponseBody.Type) async throws -> ResponseBody {
        let response = try await transport.get(path: path)
        return try decode(response: response, as: type)
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(path: String, body: RequestBody, as type: ResponseBody.Type) async throws -> ResponseBody {
        let response = try await transport.post(path: path, body: body)
        return try decode(response: response, as: type)
    }

    private func decode<ResponseBody: Decodable>(response: SidecarHTTPResponse, as type: ResponseBody.Type) throws -> ResponseBody {
        let decoder = JSONDecoder()
        if (200 ... 299).contains(response.statusCode) {
            guard let decoded = try? decoder.decode(ResponseBody.self, from: response.data) else {
                throw CompanionClientError.invalidPayload
            }
            return decoded
        }

        if let apiError = try? decoder.decode(SidecarCompanionErrorResponse.self, from: response.data) {
            throw CompanionClientError.server(apiError.error)
        }

        throw CompanionClientError.server("HTTP \(response.statusCode)")
    }
}

private struct EmptyBody: Encodable {}

private struct SidecarCompanionErrorResponse: Decodable {
    let error: String
}

enum CompanionClientError: LocalizedError {
    case invalidResponse
    case invalidPayload
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from local sidecar"
        case .invalidPayload:
            return "Invalid companion payload from local sidecar"
        case let .server(message):
            return message
        }
    }
}

struct SidecarCompanionStatusResponse: Decodable {
    struct Device: Decodable {
        let id: String
        let name: String
        let connectedAt: String
        let lastSeenAt: String
    }

    let ok: Bool
    let connected: Bool
    let connectedDevice: Device?
}

struct SidecarCompanionPairingStartResponse: Decodable {
    let ok: Bool
    let code: String
    let expiresAt: String
    let qrPayload: String
}
