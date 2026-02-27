import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: ProfileViewModel

    let copilotPricingURL = URL(string: "https://github.com/features/copilot")!

    init(isPresented: Binding<Bool>, viewModel: ProfileViewModel) {
        self._isPresented = isPresented
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Your GitHub account and Copilot connection status.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // MARK: Content split
            HStack(spacing: 0) {
                leftPane
                    .frame(minWidth: 260, maxWidth: 300)

                Divider()

                rightPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Divider()

            // MARK: Footer
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        guard let token = authViewModel.currentAccessToken() else {
            viewModel.setMissingTokenError()
            return
        }
        await viewModel.refresh(accessToken: token)
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    ProfileView(
        isPresented: .constant(true),
        viewModel: environment.profileEnvironment.profileViewModel
    )
    .environmentObject(environment.authEnvironment.authViewModel)
    .frame(minWidth: 680, minHeight: 520)
}
