import Foundation

@MainActor
final class SidecarCompanionClient {
    private let baseURL: URL
    private let sidecarLifecycle: SidecarLifecycleManaging

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:7878")!,
        sidecarLifecycle: SidecarLifecycleManaging
    ) {
        self.baseURL = baseURL
        self.sidecarLifecycle = sidecarLifecycle
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

    private func waitForSidecarReady(maxAttempts: Int, delaySeconds: TimeInterval) async -> Bool {
        for attempt in 1 ... maxAttempts {
            if await pingHealth() {
                return true
            }

            if attempt < maxAttempts {
                let nanos = UInt64(max(delaySeconds, 0.1) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }

        return false
    }

    private func isRecoverableConnectionError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .cannotConnectToHost, .timedOut, .notConnectedToInternet, .cannotFindHost:
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == URLError.networkConnectionLost.rawValue
    }

    private func get<ResponseBody: Decodable>(path: String, as type: ResponseBody.Type) async throws -> ResponseBody {
        sidecarLifecycle.startIfNeeded()
        let endpoint = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        return try await send(request: request, as: type)
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(path: String, body: RequestBody, as type: ResponseBody.Type) async throws -> ResponseBody {
        sidecarLifecycle.startIfNeeded()
        let endpoint = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request: request, as: type)
    }

    private func send<ResponseBody: Decodable>(request: URLRequest, as type: ResponseBody.Type) async throws -> ResponseBody {
        _ = await waitForSidecarReady(maxAttempts: 3, delaySeconds: 0.25)

        var lastError: Error?
        for attempt in 0 ... 1 {
            do {
                var bounded = request
                bounded.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: bounded)
                guard let http = response as? HTTPURLResponse else {
                    throw CompanionClientError.invalidResponse
                }

                let decoder = JSONDecoder()
                if (200 ... 299).contains(http.statusCode) {
                    do {
                        return try decoder.decode(ResponseBody.self, from: data)
                    } catch {
                        throw CompanionClientError.invalidPayload
                    }
                }

                if let apiError = try? decoder.decode(SidecarCompanionErrorResponse.self, from: data) {
                    throw CompanionClientError.server(apiError.error)
                }

                throw CompanionClientError.server("HTTP \(http.statusCode)")
            } catch {
                lastError = error
                if isRecoverableConnectionError(error), attempt == 0 {
                    sidecarLifecycle.startIfNeeded()
                    let ready = await waitForSidecarReady(maxAttempts: 8, delaySeconds: 0.30)
                    if !ready {
                        throw CompanionClientError.server("Local sidecar is still starting. Please retry in a moment.")
                    }
                    continue
                }

                throw error
            }
        }

        throw lastError ?? CompanionClientError.server("Unknown companion request failure")
    }

    private func pingHealth() async -> Bool {
        let endpoint = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200 ... 299).contains(http.statusCode)
        } catch {
            return false
        }
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
