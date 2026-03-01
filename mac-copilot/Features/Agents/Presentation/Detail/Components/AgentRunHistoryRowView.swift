import SwiftUI

struct AgentRunHistoryRowView: View {
    let run: AgentRun
    let format: String
    private let urlPreviewMaxCharacters = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.startedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(format.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                AgentStatusBadgeView(status: run.status)

                if let url = run.inputPayload["url"], !url.isEmpty {
                    Text(truncated(url, maxCharacters: urlPreviewMaxCharacters))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func truncated(_ value: String, maxCharacters: Int) -> String {
        guard value.count > maxCharacters else {
            return value
        }

        let endIndex = value.index(value.startIndex, offsetBy: maxCharacters)
        return String(value[..<endIndex]) + "…"
    }
}
