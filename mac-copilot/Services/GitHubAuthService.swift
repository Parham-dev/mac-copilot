import Foundation
import Security
import Combine

@MainActor
final class GitHubAuthService: ObservableObject {
    private static let configuredClientID = "Ov23lisoGOGOPveFYywW"

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var statusMessage = "Sign in required"
    @Published var errorMessage: String?
    @Published var userCode: String?
    @Published var verificationURI: String?
    @Published private(set) var clientID: String

    private var deviceCode: String?
    private var pollInterval: Int = 5
    private var didAttemptRestore = false
    private var isRestoring = false

    private let baseURL = URL(string: "http://localhost:7878")!
    private let keychain = KeychainTokenStore()

    init() {
        self.clientID = Self.configuredClientID
    }

    func restoreSessionIfNeeded() async {
        guard !didAttemptRestore, !isRestoring else { return }
        didAttemptRestore = true
        isRestoring = true
        defer { isRestoring = false }

        guard let token = keychain.readToken() else {
            statusMessage = "Sign in required"
            return
        }

        statusMessage = "Restoring session…"
        errorMessage = nil

        let sidecarReady = await waitForSidecarReady(maxAttempts: 5, delaySeconds: 0.35)
        guard sidecarReady else {
            isAuthenticated = false
            statusMessage = "Local sidecar is offline. Relaunch app to retry."
            errorMessage = "Could not connect to localhost:7878"
            return
        }

        let maxAttempts = 2
        for attempt in 1 ... maxAttempts {
            do {
                _ = try await post(path: "auth", body: AuthRequest(token: token), as: AuthResponse.self)
                isAuthenticated = true
                statusMessage = "Signed in"
                return
            } catch {
                if isRecoverableConnectionError(error), attempt < maxAttempts {
                    statusMessage = "Reconnecting to local sidecar…"
                    let retryDelay = UInt64(300_000_000 * UInt64(attempt))
                    try? await Task.sleep(nanoseconds: retryDelay)
                    continue
                }

                if isRecoverableConnectionError(error) {
                    isAuthenticated = false
                    statusMessage = "Local sidecar is offline. Relaunch app to retry."
                    errorMessage = error.localizedDescription
                    return
                }

                keychain.deleteToken()
                isAuthenticated = false
                statusMessage = "Session expired. Please sign in again."
                errorMessage = error.localizedDescription
                return
            }
        }

        isAuthenticated = false
        statusMessage = "Sign in required"
    }

    func startDeviceFlow() async {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientID.isEmpty else {
            errorMessage = "App OAuth Client ID is missing. Contact support."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await post(path: "auth/start", body: StartAuthRequest(clientId: trimmedClientID), as: StartAuthResponse.self)
            deviceCode = response.deviceCode
            userCode = response.userCode
            verificationURI = response.verificationURIComplete ?? response.verificationURI
            pollInterval = max(response.interval ?? 5, 2)
            statusMessage = "Open GitHub and approve access"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Could not start sign-in"
        }

        isLoading = false
    }

    func pollForAuthorization() async {
        guard let deviceCode else {
            errorMessage = "Start sign-in first"
            return
        }

        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientID.isEmpty else {
            errorMessage = "Client ID is required"
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = "Waiting for GitHub approval…"

        var transientFailures = 0

        while true {
            do {
                let response = try await post(path: "auth/poll", body: PollAuthRequest(clientId: trimmedClientID, deviceCode: deviceCode), as: PollAuthResponse.self)
            transientFailures = 0

                switch response.status {
                case "authorized":
                    guard let token = response.accessToken else {
                        throw AuthError.missingToken
                    }
                    try keychain.saveToken(token)
                    isAuthenticated = true
                    statusMessage = "Signed in"
                    isLoading = false
                    return
                case "authorization_pending":
                    try await waitForPoll(seconds: response.interval ?? pollInterval)
                case "slow_down":
                    pollInterval += 5
                    try await waitForPoll(seconds: response.interval ?? pollInterval)
                case "access_denied":
                    throw AuthError.accessDenied
                case "expired_token":
                    throw AuthError.codeExpired
                default:
                    throw AuthError.unexpectedStatus(response.status)
                }
            } catch {
                if isRecoverableConnectionError(error), transientFailures < 5 {
                    transientFailures += 1
                    statusMessage = "Reconnecting to local sidecar…"
                    _ = await waitForSidecarReady(maxAttempts: 4, delaySeconds: 0.5)
                    try? await waitForPoll(seconds: 1)
                    continue
                }

                isLoading = false
                isAuthenticated = false
                errorMessage = error.localizedDescription
                statusMessage = "Sign-in failed"
                return
            }
        }
    }

    func signOut() {
        keychain.deleteToken()
        isAuthenticated = false
        userCode = nil
        verificationURI = nil
        deviceCode = nil
        didAttemptRestore = false
        statusMessage = "Signed out"
    }

    func currentAccessToken() -> String? {
        keychain.readToken()
    }

    private func waitForPoll(seconds: Int) async throws {
        let clamped = max(seconds, 1)
        try await Task.sleep(nanoseconds: UInt64(clamped) * 1_000_000_000)
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
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
        if nsError.domain == NSURLErrorDomain, nsError.code == URLError.networkConnectionLost.rawValue {
            return true
        }

        return false
    }
}

private struct StartAuthRequest: Encodable {
    let clientId: String
}

private struct PollAuthRequest: Encodable {
    let clientId: String
    let deviceCode: String
}

private struct AuthRequest: Encodable {
    let token: String
}

private struct StartAuthResponse: Decodable {
    let ok: Bool
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let verificationURIComplete: String?
    let interval: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case verificationURIComplete = "verification_uri_complete"
        case interval
    }
}

private struct PollAuthResponse: Decodable {
    let ok: Bool
    let status: String
    let accessToken: String?
    let interval: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case status
        case accessToken = "access_token"
        case interval
    }
}

private struct AuthResponse: Decodable {
    let ok: Bool
    let authenticated: Bool?
}

private struct APIErrorResponse: Decodable {
    let ok: Bool
    let error: String
}

private enum AuthError: LocalizedError {
    case missingToken
    case accessDenied
    case codeExpired
    case invalidResponse
    case unexpectedStatus(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Auth completed but no access token was returned."
        case .accessDenied:
            return "GitHub sign-in was denied."
        case .codeExpired:
            return "Device code expired. Start sign-in again."
        case .invalidResponse:
            return "Invalid response from sidecar."
        case .unexpectedStatus(let status):
            return "Unexpected auth status: \(status)"
        case .server(let message):
            return message
        }
    }
}

private struct KeychainTokenStore {
    private let service = "CopilotForge"
    private let account = "github_access_token"

    func saveToken(_ token: String) throws {
        deleteToken()

        guard let data = token.data(using: .utf8) else {
            throw AuthError.server("Unable to encode token")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.server("Keychain save failed (\(status))")
        }
    }

    func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
