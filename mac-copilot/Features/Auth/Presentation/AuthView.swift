import SwiftUI

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
                        if let verificationURI = authViewModel.verificationURI,
                           let url = URL(string: verificationURI) {
                            openURL(url)
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
}

#Preview {
    AuthView()
    .environmentObject(AppEnvironment.preview().authEnvironment.authViewModel)
}
