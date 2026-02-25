import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    private let copilotPricingURL = URL(string: "https://github.com/features/copilot")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView

                CopilotStatusCardView(report: viewModel.copilotReport, pricingURL: copilotPricingURL)

                if let profile = viewModel.userProfile {
                    UserProfileSummaryView(profile: profile)
                }

                if viewModel.isLoading {
                    ProgressView("Loading GitHub data…")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if !viewModel.checks.isEmpty {
                    Text("Available Options")
                        .font(.headline)

                    ForEach(viewModel.checks) { check in
                        EndpointCheckCardView(check: check)
                    }
                }

                if !viewModel.rawUserJSON.isEmpty {
                    Text("Raw /user Preview")
                        .font(.headline)

                    Text(viewModel.rawUserJSON)
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

    private var headerView: some View {
        HStack {
            Text("Profile")
                .font(.title2.bold())

            Spacer()

            Button("Refresh") {
                Task { await refresh() }
            }
            .disabled(viewModel.isLoading)
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
    ProfileView(viewModel: environment.sharedProfileViewModel())
        .environmentObject(environment.authViewModel)
}
