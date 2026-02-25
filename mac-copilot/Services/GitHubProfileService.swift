import Foundation
import Combine

@MainActor
final class GitHubProfileService: ObservableObject {
    struct EndpointCheck: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let statusCode: Int
        let available: Bool
        let preview: String
    }

    struct UserProfile {
        let login: String
        let name: String?
        let email: String?
        let company: String?
        let publicRepos: Int?
        let followers: Int?
        let plan: String?
    }

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile?
    @Published var rawUserJSON = ""
    @Published var checks: [EndpointCheck] = []

    private let baseURL = URL(string: "https://api.github.com")!
    private let localBaseURL = URL(string: "http://localhost:7878")!

    func refresh(accessToken: String) async {
        isLoading = true
        errorMessage = nil
        checks = []
        NSLog("[CopilotForge][Profile] Refresh started")

        do {
            let userResult = try await request(path: "user", token: accessToken)
            rawUserJSON = prettyPrinted(userResult.data)
            userProfile = parseUserProfile(from: userResult.data)
            NSLog("[CopilotForge][Profile] /user status=%d", userResult.statusCode)
            NSLog("[CopilotForge][Profile] /user payload=\n%@", rawUserJSON)

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
            NSLog("[CopilotForge][Profile] /user/emails status=%d body=%@", emailResult.statusCode, preview(from: emailResult.data))
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
            NSLog("[CopilotForge][Profile] local:/copilot/report status=%d body=%@", copilotResult.statusCode, preview(from: copilotResult.data))
            builtChecks.append(
                EndpointCheck(
                    name: "Copilot SDK Session Report",
                    path: "local:/copilot/report",
                    statusCode: copilotResult.statusCode,
                    available: (200 ... 299).contains(copilotResult.statusCode),
                    preview: preview(from: copilotResult.data)
                )
            )

            checks = builtChecks
            NSLog("[CopilotForge][Profile] Refresh completed with %d checks", checks.count)
        } catch {
            errorMessage = error.localizedDescription
            NSLog("[CopilotForge][Profile] Refresh failed: %@", error.localizedDescription)
        }

        isLoading = false
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
