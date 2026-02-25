import SwiftUI

struct CopilotStatusCardView: View {
    let report: CopilotReport?
    let pricingURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Copilot")
                .font(.headline)

            if let report {
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
                    Link("Get Copilot Subscription", destination: pricingURL)
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
