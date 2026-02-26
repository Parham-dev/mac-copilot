import Foundation

final class GitHubProfileRepository: ProfileRepository {
    private let baseURL = URL(string: "https://api.github.com")!
    private let localBaseURL = URL(string: "http://127.0.0.1:7878")!
    private let sidecarAuthClient: SidecarAuthClient?

    @MainActor
    init(sidecarAuthClient: SidecarAuthClient? = nil) {
        self.sidecarAuthClient = sidecarAuthClient
    }

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

        var copilotResult = try await requestLocal(path: "copilot/report")
        var copilotReport = parseCopilotReport(from: copilotResult.data)

        if let client = sidecarAuthClient,
           shouldReauthorizeSidecar(using: copilotReport) {
            NSLog(
                "[CopilotForge][Profile] copilot report stale, reauth sidecar (sessionReady=%@ usingGitHubToken=%@)",
                (copilotReport?.sessionReady == true) ? "true" : "false",
                (copilotReport?.usingGitHubToken == true) ? "true" : "false"
            )
            do {
                let refreshed = try await reauthorizeAndRefreshCopilotReport(client: client, accessToken: accessToken)
                copilotResult = refreshed.report
                copilotReport = refreshed.parsed

                NSLog(
                    "[CopilotForge][Profile] reauth outcome (sessionReady=%@ usingGitHubToken=%@)",
                    (copilotReport?.sessionReady == true) ? "true" : "false",
                    (copilotReport?.usingGitHubToken == true) ? "true" : "false"
                )
            } catch {
                NSLog("[CopilotForge][Profile] sidecar reauth failed: %@", error.localizedDescription)
                SentryMonitoring.captureError(
                    error,
                    category: "profile_copilot_reauth",
                    throttleKey: "reauth_failed"
                )
            }
        }

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
            copilotReport: copilotReport,
            rawUserJSON: rawUserJSON,
            checks: builtChecks
        )
    }

    private func shouldReauthorizeSidecar(using report: CopilotReport?) -> Bool {
        guard let report else {
            return true
        }

        return !report.sessionReady || !report.usingGitHubToken
    }

    private func reauthorizeAndRefreshCopilotReport(
        client: SidecarAuthClient,
        accessToken: String
    ) async throws -> (report: (statusCode: Int, data: Data), parsed: CopilotReport?) {
        var latestReport: (statusCode: Int, data: Data)?
        var latestParsed: CopilotReport?
        var lastError: Error?

        for attempt in 1 ... 3 {
            do {
                _ = try await client.authorize(token: accessToken)

                let authStatusResponse = try await requestLocal(path: "auth/status")
                let sidecarAuthenticated = parseAuthStatus(from: authStatusResponse.data) ?? false

                let report = try await requestLocal(path: "copilot/report")
                latestReport = report
                latestParsed = parseCopilotReport(from: report.data)

                if sidecarAuthenticated, latestParsed?.sessionReady == true {
                    return (report, latestParsed)
                }
            } catch {
                lastError = error
            }

            if attempt < 3 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 250_000_000)
            }
        }

        if let latestReport {
            return (latestReport, latestParsed)
        }

        throw lastError ?? ProfileError.invalidResponse
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

    private func parseAuthStatus(from data: Data) -> Bool? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return object["authenticated"] as? Bool
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
