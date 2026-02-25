import Foundation

struct StartAuthRequest: Encodable {
    let clientId: String
}

struct PollAuthRequest: Encodable {
    let clientId: String
    let deviceCode: String
}

struct AuthRequest: Encodable {
    let token: String
}

struct StartAuthResponse: Decodable {
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

struct PollAuthResponse: Decodable {
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

struct AuthResponse: Decodable {
    let ok: Bool
    let authenticated: Bool?
}

struct APIErrorResponse: Decodable {
    let ok: Bool
    let error: String
}

enum AuthError: LocalizedError {
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
