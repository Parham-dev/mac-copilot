import SwiftUI

struct AgentRunFooterBarView: View {
    let modelErrorMessage: String?
    let errorMessage: String?
    let isRunning: Bool
    let runButtonTitle: String
    let latestRun: AgentRun?
    let runActivity: String?
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let modelErrorMessage,
               !modelErrorMessage.isEmpty {
                Text(modelErrorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let errorMessage,
               !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(runButtonTitle, action: onRun)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)

                if let latestRun {
                    HStack(spacing: 6) {
                        Text("Latest run")
                            .foregroundStyle(.secondary)
                        AgentStatusBadgeView(status: latestRun.status)
                    }
                }

                Spacer(minLength: 0)

                if isRunning,
                   let runActivity,
                   !runActivity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("AI is working: \(runActivity)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
