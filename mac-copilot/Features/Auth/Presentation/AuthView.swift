import SwiftUI
import AppKit

struct AuthView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
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
                        await authViewModel.startDeviceFlow()

                        if let verificationURI = authViewModel.verificationURI {
                            openVerificationPage(verificationURI)
                        }

                        if authViewModel.userCode != nil {
                            await authViewModel.pollForAuthorization()
                        }
                    }
                }
                .disabled(authViewModel.isLoading)
            }

            if authViewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if let userCode = authViewModel.userCode {
                AuthCodeRowView(userCode: userCode)
            }

            if let verificationURI = authViewModel.verificationURI,
               let url = URL(string: verificationURI) {
                Link("Open GitHub Verification Page", destination: url)
            }

            AuthStatusBlockView(
                statusMessage: authViewModel.statusMessage,
                errorMessage: authViewModel.errorMessage
            )
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func openVerificationPage(_ rawURI: String) {
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = URL(string: trimmed), url.scheme != nil {
            if !NSWorkspace.shared.open(url) {
                openURL(url)
            }
            return
        }

        if let url = URL(string: "https://\(trimmed)") {
            if !NSWorkspace.shared.open(url) {
                openURL(url)
            }
        }
    }
}

#Preview {
    AuthView()
    .environmentObject(AppEnvironment.preview().authEnvironment.authViewModel)
}
