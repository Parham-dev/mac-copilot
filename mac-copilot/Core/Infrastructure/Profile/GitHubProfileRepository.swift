import Foundation

final class GitHubProfileRepository: ProfileRepository {
    private let baseURL = URL(string: "https://api.github.com")!
    private let localBaseURL = URL(string: "http://localhost:7878")!

    func fetchProfile(accessToken: String) async throws -> ProfileSnapshot {
        let userResult = try await request(path: "user", token: accessToken)
        let rawUserJSON = prettyPrinted(userResult.data)

        var builtChecks: [EndpointCheck] = [
            EndpointCheck(
                name: "User Profile",
                path: "/user",
                statusCode: userResult.statusCode,
                available: (200 ... 299).contains(userResult.statusCode),
                preview: preview(from: userResult.data)
            )
        ]

        let emailResult = try await request(path: "user/emails", token: accessToken)
        builtChecks.append(
            EndpointCheck(
                name: "User Emails (scope: user:email)",
                path: "/user/emails",
                statusCode: emailResult.statusCode,
                available: (200 ... 299).contains(emailResult.statusCode),
                preview: preview(from: emailResult.data)
            )
        )

        let copilotResult = try await requestLocal(path: "copilot/report")
        builtChecks.append(
            EndpointCheck(
                name: "Copilot SDK Session Report",
                path: "local:/copilot/report",
                statusCode: copilotResult.statusCode,
                available: (200 ... 299).contains(copilotResult.statusCode),
                preview: preview(from: copilotResult.data)
            )
        )

        return ProfileSnapshot(
            userProfile: parseUserProfile(from: userResult.data),
            copilotReport: parseCopilotReport(from: copilotResult.data),
            rawUserJSON: rawUserJSON,
            checks: builtChecks
        )
    }

    private func request(path: String, token: String) async throws -> (statusCode: Int, data: Data) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }

        return (http.statusCode, data)
    }

    private func requestLocal(path: String) async throws -> (statusCode: Int, data: Data) {
        var request = URLRequest(url: localBaseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }

        return (http.statusCode, data)
    }

    private func parseUserProfile(from data: Data) -> UserProfile? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let planName = (object["plan"] as? [String: Any])?["name"] as? String

        return UserProfile(
            login: object["login"] as? String ?? "",
            name: object["name"] as? String,
            email: object["email"] as? String,
            company: object["company"] as? String,
            publicRepos: object["public_repos"] as? Int,
            followers: object["followers"] as? Int,
            plan: planName
        )
    }

    private func parseCopilotReport(from data: Data) -> CopilotReport? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return CopilotReport(
            sessionReady: object["sessionReady"] as? Bool ?? false,
            usingGitHubToken: object["usingGitHubToken"] as? Bool ?? false,
            oauthScope: object["oauthScope"] as? String,
            lastAuthAt: object["lastAuthAt"] as? String,
            lastAuthError: object["lastAuthError"] as? String
        )
    }

    private func preview(from data: Data) -> String {
        if let pretty = try? prettyPrintedObject(from: data) {
            return String(pretty.prefix(220))
        }

        return String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
    }

    private func prettyPrinted(_ data: Data) -> String {
        (try? prettyPrintedObject(from: data)) ?? (String(data: data, encoding: .utf8) ?? "")
    }

    private func prettyPrintedObject(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(data: prettyData, encoding: .utf8) ?? ""
    }
}

private enum ProfileError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from GitHub API."
        }
    }
}
