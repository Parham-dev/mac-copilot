import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: GitHubAuthService
    @StateObject private var profileService = GitHubProfileService()

    private let copilotPricingURL = URL(string: "https://github.com/features/copilot")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Profile")
                        .font(.title2.bold())

                    Spacer()

                    Button("Refresh") {
                        Task { await refresh() }
                    }
                    .disabled(profileService.isLoading)
                }

                copilotStatusCard

                if let profile = profileService.userProfile {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("@\(profile.login)")
                            .font(.headline)
                        if let name = profile.name, !name.isEmpty {
                            Text(name)
                        }
                        if let email = profile.email, !email.isEmpty {
                            Text(email)
                                .foregroundStyle(.secondary)
                        }
                        if let company = profile.company, !company.isEmpty {
                            Text(company)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            if let repos = profile.publicRepos {
                                Text("Repos: \(repos)")
                            }
                            if let followers = profile.followers {
                                Text("Followers: \(followers)")
                            }
                            if let plan = profile.plan {
                                Text("Plan: \(plan)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if profileService.isLoading {
                    ProgressView("Loading GitHub data…")
                }

                if let errorMessage = profileService.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if !profileService.checks.isEmpty {
                    Text("Available Options")
                        .font(.headline)

                    ForEach(profileService.checks) { check in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: check.available ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundStyle(check.available ? .green : .orange)
                                Text(check.name)
                                Text("(\(check.statusCode))")
                                    .foregroundStyle(.secondary)
                            }
                            Text(check.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(check.preview)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                if !profileService.rawUserJSON.isEmpty {
                    Text("Raw /user Preview")
                        .font(.headline)

                    Text(profileService.rawUserJSON)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        guard let token = authService.currentAccessToken() else {
            profileService.errorMessage = "No GitHub token found. Sign in again."
            return
        }

        await profileService.refresh(accessToken: token)
    }

    @ViewBuilder
    private var copilotStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Copilot")
                .font(.headline)

            if let report = profileService.copilotReport {
                HStack(spacing: 8) {
                    Image(systemName: report.sessionReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(report.sessionReady ? .green : .orange)
                    Text(report.sessionReady ? "Connected and available" : "Not connected")
                        .fontWeight(.medium)
                }

                Text(report.sessionReady ? "Copilot session is active for this user." : "Copilot session is unavailable for this account or token.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let scope = report.oauthScope, !scope.isEmpty {
                    Text("OAuth scopes: \(scope)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastAuthError = report.lastAuthError, !lastAuthError.isEmpty {
                    Text("Last auth error: \(lastAuthError)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !report.sessionReady {
                    Link("Get Copilot Subscription", destination: copilotPricingURL)
                        .buttonStyle(.link)
                }
            } else {
                Text("Checking Copilot availability…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ProfileView()
        .environmentObject(GitHubAuthService())
}
