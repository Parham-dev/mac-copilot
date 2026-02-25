import SwiftUI

struct OnboardingRootView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if appEnvironment.launchPhase == .checking {
                loadingView
            } else if authViewModel.isAuthenticated {
                ContentView(
                    shellViewModel: appEnvironment.shellEnvironment.shellViewModel,
                    projectCreationService: appEnvironment.shellEnvironment.projectCreationService
                )
            } else {
                onboardingView
            }
        }
        .task {
            await appEnvironment.bootstrapIfNeeded()
        }
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
    .environmentObject(environment.shellEnvironment)
    .environmentObject(environment.companionEnvironment)
}
