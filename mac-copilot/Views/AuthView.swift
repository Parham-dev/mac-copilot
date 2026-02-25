import SwiftUI
import AppKit

struct AuthView: View {
    @EnvironmentObject private var authService: GitHubAuthService
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect GitHub")
                .font(.title2.bold())

            Text("Sign in with GitHub Device Flow to enable Copilot sessions.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Connect GitHub") {
                    Task {
                        await authService.startDeviceFlow()
                        if let verificationURI = authService.verificationURI,
                           let url = URL(string: verificationURI) {
                            openURL(url)
                            await authService.pollForAuthorization()
                        }
                    }
                }
                .disabled(authService.isLoading)
            }

            if authService.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if let userCode = authService.userCode {
                HStack(spacing: 10) {
                    Text("Enter this code on GitHub: \(userCode)")
                        .font(.headline)

                    Button("Copy Code") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(userCode, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let verificationURI = authService.verificationURI,
               let url = URL(string: verificationURI) {
                Link("Open GitHub Verification Page", destination: url)
            }

            Text(authService.statusMessage)
                .foregroundStyle(.secondary)

            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
    }
}

#Preview {
    AuthView()
        .environmentObject(GitHubAuthService())
}
