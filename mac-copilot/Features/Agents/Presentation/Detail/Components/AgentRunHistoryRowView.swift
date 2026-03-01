import SwiftUI

struct AgentRunHistoryRowView: View {
    let run: AgentRun
    let format: String
    let onDelete: () -> Void
    private let urlPreviewMaxCharacters = 42
    @State private var isHovered = false

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

                if isHovered {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                }
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
        .onHover { inside in
            isHovered = inside
        }
    }

    private func truncated(_ value: String, maxCharacters: Int) -> String {
        guard value.count > maxCharacters else {
            return value
        }

        let endIndex = value.index(value.startIndex, offsetBy: maxCharacters)
        return String(value[..<endIndex]) + "…"
    }
}
