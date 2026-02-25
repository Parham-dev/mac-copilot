import Foundation

@MainActor
final class SidecarAuthClient {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:7878")!) {
        self.baseURL = baseURL
    }

    func authorize(token: String) async throws -> AuthResponse {
        try await post(path: "auth", body: AuthRequest(token: token), as: AuthResponse.self)
    }

    func startAuth(clientId: String) async throws -> StartAuthResponse {
        try await post(path: "auth/start", body: StartAuthRequest(clientId: clientId), as: StartAuthResponse.self)
    }

    func pollAuth(clientId: String, deviceCode: String) async throws -> PollAuthResponse {
        try await post(path: "auth/poll", body: PollAuthRequest(clientId: clientId, deviceCode: deviceCode), as: PollAuthResponse.self)
    }

    func waitForSidecarReady(maxAttempts: Int, delaySeconds: TimeInterval) async -> Bool {
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

    func isRecoverableConnectionError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .cannotConnectToHost, .timedOut, .notConnectedToInternet, .cannotFindHost:
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == URLError.networkConnectionLost.rawValue {
            return true
        }

        return false
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        as type: ResponseBody.Type
    ) async throws -> ResponseBody {
        SidecarManager.shared.startIfNeeded()

        var lastError: Error?
        for attempt in 0 ... 1 {
            do {
                return try await performPost(path: path, body: body, as: type)
            } catch {
                lastError = error
                if isRecoverableConnectionError(error), attempt == 0 {
                    NSLog("[CopilotForge][Auth] Recoverable connection error. Restarting sidecar and retrying %@", path)
                    SidecarManager.shared.restart()
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    continue
                }
                throw error
            }
        }

        throw lastError ?? AuthError.server("Unknown auth request failure")
    }

    private func performPost<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        as type: ResponseBody.Type
    ) async throws -> ResponseBody {
        let endpoint = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        let decoder = JSONDecoder()

        if (200 ... 299).contains(http.statusCode) {
            do {
                return try decoder.decode(ResponseBody.self, from: data)
            } catch {
                logHTTPDebug(path: path, statusCode: http.statusCode, data: data, error: error)
                throw AuthError.server("Unexpected response from sidecar. Check Xcode logs for payload details.")
            }
        }

        logHTTPDebug(path: path, statusCode: http.statusCode, data: data, error: nil)

        if http.statusCode == 404 {
            throw AuthError.server("Auth service is out of date (HTTP 404). Fully quit CopilotForge and relaunch to restart the sidecar.")
        }

        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
            throw AuthError.server(apiError.error)
        }

        throw AuthError.server("HTTP \(http.statusCode)")
    }

    private func logHTTPDebug(path: String, statusCode: Int, data: Data, error: Error?) {
        let rawBody: String
        if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            rawBody = body
        } else {
            rawBody = "<non-utf8 or empty: \(data.count) bytes>"
        }

        if let error {
            NSLog("[CopilotForge][Auth] POST /%@ -> %d decode error: %@ | body: %@", path, statusCode, error.localizedDescription, rawBody)
        } else {
            NSLog("[CopilotForge][Auth] POST /%@ -> %d | body: %@", path, statusCode, rawBody)
        }
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
