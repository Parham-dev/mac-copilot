import Foundation

@MainActor
final class SidecarAuthClient {
    private let transport: SidecarHTTPClient

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:7878")!,
        sidecarLifecycle: SidecarLifecycleManaging
    ) {
        self.transport = SidecarHTTPClient(baseURL: baseURL, sidecarLifecycle: sidecarLifecycle)
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

    func isRecoverableConnectionError(_ error: Error) -> Bool {
        transport.isRecoverableConnectionError(error)
    }

    func waitForSidecarReady(maxAttempts: Int, delaySeconds: TimeInterval) async -> Bool {
        await transport.waitForSidecarReady(maxAttempts: maxAttempts, delaySeconds: delaySeconds)
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        as type: ResponseBody.Type
    ) async throws -> ResponseBody {
        let response = try await transport.post(path: path, body: body)
        let data = response.data
        let statusCode = response.statusCode

        let decoder = JSONDecoder()

        if (200 ... 299).contains(statusCode) {
            do {
                return try decoder.decode(ResponseBody.self, from: data)
            } catch {
                logHTTPDebug(path: path, statusCode: statusCode, data: data, error: error)
                throw AuthError.server("Unexpected response from sidecar. Check Xcode logs for payload details.")
            }
        }

        logHTTPDebug(path: path, statusCode: statusCode, data: data, error: nil)

        if statusCode == 404 {
            throw AuthError.server("Auth service is out of date (HTTP 404). Fully quit CopilotForge and relaunch to restart the sidecar.")
        }

        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
            throw AuthError.server(apiError.error)
        }

        throw AuthError.server("HTTP \(statusCode)")
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

}
