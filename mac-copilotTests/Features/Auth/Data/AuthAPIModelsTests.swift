import Foundation
import Testing
@testable import mac_copilot

struct AuthAPIModelsTests {

    // MARK: - Request encoding

    @Test(.tags(.unit)) func startAuthRequest_encodesClientId() throws {
        let request = StartAuthRequest(clientId: "my-client-id")
        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(json["clientId"] == "my-client-id")
    }

    @Test(.tags(.unit)) func pollAuthRequest_encodesClientIdAndDeviceCode() throws {
        let request = PollAuthRequest(clientId: "client-abc", deviceCode: "device-xyz")
        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(json["clientId"] == "client-abc")
        #expect(json["deviceCode"] == "device-xyz")
    }

    @Test(.tags(.unit)) func authRequest_encodesToken() throws {
        let request = AuthRequest(token: "ghp_secret")
        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(json["token"] == "ghp_secret")
    }

    // MARK: - StartAuthResponse decoding

    @Test(.tags(.unit)) func startAuthResponse_decodesSnakeCaseKeys() throws {
        let json = """
        {
            "ok": true,
            "device_code": "dev-abc",
            "user_code": "WXYZ-1234",
            "verification_uri": "https://github.com/login/device",
            "verification_uri_complete": "https://github.com/login/device?code=WXYZ-1234",
            "interval": 5
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(StartAuthResponse.self, from: json)

        #expect(response.ok == true)
        #expect(response.deviceCode == "dev-abc")
        #expect(response.userCode == "WXYZ-1234")
        #expect(response.verificationURI == "https://github.com/login/device")
        #expect(response.verificationURIComplete == "https://github.com/login/device?code=WXYZ-1234")
        #expect(response.interval == 5)
    }

    @Test(.tags(.unit)) func startAuthResponse_decodesWithOptionalFieldsMissing() throws {
        let json = """
        {
            "ok": true,
            "device_code": "dev-abc",
            "user_code": "WXYZ-1234",
            "verification_uri": "https://github.com/login/device"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(StartAuthResponse.self, from: json)

        #expect(response.verificationURIComplete == nil)
        #expect(response.interval == nil)
    }

    // MARK: - PollAuthResponse decoding

    @Test(.tags(.unit)) func pollAuthResponse_decodesAuthorizedWithToken() throws {
        let json = """
        {
            "ok": true,
            "status": "authorized",
            "access_token": "ghp_realtoken",
            "interval": 5
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PollAuthResponse.self, from: json)

        #expect(response.ok == true)
        #expect(response.status == "authorized")
        #expect(response.accessToken == "ghp_realtoken")
        #expect(response.interval == 5)
    }

    @Test(.tags(.unit)) func pollAuthResponse_decodesAuthorizationPendingWithoutToken() throws {
        let json = """
        {
            "ok": true,
            "status": "authorization_pending"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PollAuthResponse.self, from: json)

        #expect(response.status == "authorization_pending")
        #expect(response.accessToken == nil)
        #expect(response.interval == nil)
    }

    // MARK: - AuthResponse decoding

    @Test(.tags(.unit)) func authResponse_decodesOkAndAuthenticated() throws {
        let json = """
        { "ok": true, "authenticated": true }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AuthResponse.self, from: json)

        #expect(response.ok == true)
        #expect(response.authenticated == true)
    }

    @Test(.tags(.unit)) func authResponse_decodesWithAuthenticatedMissing() throws {
        let json = """
        { "ok": true }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(AuthResponse.self, from: json)
        #expect(response.authenticated == nil)
    }

    // MARK: - APIErrorResponse decoding

    @Test(.tags(.unit)) func apiErrorResponse_decodesErrorMessage() throws {
        let json = """
        { "ok": false, "error": "Client not authorized" }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(APIErrorResponse.self, from: json)

        #expect(response.ok == false)
        #expect(response.error == "Client not authorized")
    }

    // MARK: - AuthError.errorDescription

    @Test(.tags(.unit)) func authError_missingToken_hasExpectedDescription() {
        #expect(AuthError.missingToken.errorDescription == "Auth completed but no access token was returned.")
    }

    @Test(.tags(.unit)) func authError_accessDenied_hasExpectedDescription() {
        #expect(AuthError.accessDenied.errorDescription == "GitHub sign-in was denied.")
    }

    @Test(.tags(.unit)) func authError_codeExpired_hasExpectedDescription() {
        #expect(AuthError.codeExpired.errorDescription == "Device code expired. Start sign-in again.")
    }

    @Test(.tags(.unit)) func authError_invalidResponse_hasExpectedDescription() {
        #expect(AuthError.invalidResponse.errorDescription == "Invalid response from sidecar.")
    }

    @Test(.tags(.unit)) func authError_unexpectedStatus_embedsStatusInDescription() {
        let error = AuthError.unexpectedStatus("slow_down")
        #expect(error.errorDescription == "Unexpected auth status: slow_down")
    }

    @Test(.tags(.unit)) func authError_server_embedsMessageInDescription() {
        let error = AuthError.server("Quota exceeded")
        #expect(error.errorDescription == "Quota exceeded")
    }
}
