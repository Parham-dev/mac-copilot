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

            if let verificationURI = authViewModel.verificationURI,
               let url = URL(string: verificationURI) {
                Link("Open GitHub Verification Page", destination: url)
            }

            Text(authViewModel.statusMessage)
                .foregroundStyle(.secondary)

            if let errorMessage = authViewModel.errorMessage {
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
    .environmentObject(AppEnvironment.preview().authViewModel)
}
