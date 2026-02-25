import SwiftUI
import AppKit

struct ChatMessageRow: View {
    let message: ChatMessage
    let statusChips: [String]
    let isStreaming: Bool

    var body: some View {
        HStack {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 6) {
                    bubble(color: .gray.opacity(0.18), alignment: .leading)

                    if isStreaming {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Working…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 6)
                    }

                    if !statusChips.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(statusChips, id: \.self) { chip in
                                    Text(chip)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.gray.opacity(0.14))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.leading, 6)
                    }

                    if !message.text.isEmpty {
                        Button {
                            copyToClipboard(message.text)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 6)
                    }
                }
                Spacer(minLength: 36)
            } else {
                Spacer(minLength: 36)
                bubble(color: .accentColor.opacity(0.2), alignment: .trailing)
            }
        }
    }

    private func bubble(color: Color, alignment: Alignment) -> some View {
        Text(message.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: 700, alignment: alignment)
    }

    private func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
