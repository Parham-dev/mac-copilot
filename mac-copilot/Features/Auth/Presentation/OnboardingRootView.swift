import SwiftUI

struct OnboardingRootView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch appEnvironment.launchPhase {
            case .checking:
                loadingView
            case .failed(let message):
                launchFailureView(message: message)
            case .ready:
                if authViewModel.isAuthenticated {
                    ContentView()
                } else {
                    onboardingView
                }
            }
        }
        .task {
            await appEnvironment.bootstrapIfNeeded()
        }
    }

    private func launchFailureView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 36))

            Text("Startup failed")
                .font(.title3.weight(.semibold))

            Text("CopilotForge could not initialize local storage.")
                .foregroundStyle(.secondary)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Quit the app and relaunch. If this continues, check disk permissions and free space.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Preparing CopilotForge")
                .font(.title3.weight(.semibold))
            Text("Checking local runtime and restoring your GitHub session…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var onboardingView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color.clear,
                    Color.secondary.opacity(0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Welcome to CopilotForge")
                        .font(.largeTitle.weight(.bold))
                    Text("Connect GitHub to start project-aware Copilot sessions.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                AuthView()
                    .environmentObject(authViewModel)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(24)
            .frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    OnboardingRootView()
        .environmentObject(environment)
        .environmentObject(environment.authEnvironment.authViewModel)
        .environmentObject(environment.featureRegistry)
        .environmentObject(environment.projectsEnvironment)
        .environmentObject(environment.projectsShellBridge)
        .environmentObject(environment.companionEnvironment)
}
