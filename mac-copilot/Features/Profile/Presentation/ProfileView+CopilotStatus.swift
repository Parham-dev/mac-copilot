import SwiftUI

extension ProfileView {
    var copilotStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Copilot")
                .font(.headline)

            if let report = viewModel.copilotReport {
                copilotStatusCard(report)
            } else if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking Copilot status…")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                Text("No Copilot data available.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            if let err = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    func copilotStatusCard(_ report: CopilotReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: report.sessionReady
                      ? "checkmark.circle.fill"
                      : "xmark.circle.fill")
                    .foregroundStyle(report.sessionReady ? .green : .orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.sessionReady ? "Connected" : "Not connected")
                        .fontWeight(.semibold)
                    Text(report.sessionReady
                         ? "Copilot session is active."
                         : "Session unavailable for this token.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if let scope = report.oauthScope, !scope.isEmpty {
                    copilotDetailRow(icon: "key", label: "OAuth Scope", value: scope)
                }
                if let lastAuth = report.lastAuthAt, !lastAuth.isEmpty {
                    copilotDetailRow(icon: "clock", label: "Last Auth", value: lastAuth)
                }
                if let authErr = report.lastAuthError, !authErr.isEmpty {
                    copilotDetailRow(icon: "exclamationmark.triangle", label: "Auth Error",
                                     value: authErr, valueColor: .orange)
                }
            }

            if !report.sessionReady {
                Link(destination: copilotPricingURL) {
                    Label("Get Copilot Subscription", systemImage: "arrow.up.right.square")
                        .font(.callout)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    func copilotDetailRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(valueColor)
                .textSelection(.enabled)
        }
    }
}
