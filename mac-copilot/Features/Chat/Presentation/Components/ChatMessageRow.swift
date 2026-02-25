import SwiftUI
import AppKit
#if canImport(Textual)
import Textual
#endif

struct ChatMessageRow: View {
    let message: ChatMessage
    let statusChips: [String]
    let toolExecutions: [ChatMessage.ToolExecution]
    let isStreaming: Bool

    @State private var showsToolDetails = false

    var body: some View {
        HStack {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 6) {
                    assistantBubble(color: .gray.opacity(0.18), alignment: .leading)

                    if !statusChips.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(statusChips.enumerated()), id: \.offset) { _, chip in
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

                    if !toolExecutions.isEmpty {
                        DisclosureGroup(isExpanded: $showsToolDetails) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(toolExecutions) { tool in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: tool.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                                .foregroundStyle(tool.success ? .green : .red)
                                            Text(tool.toolName)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }

                                        if let details = tool.details, !details.isEmpty {
                                            Text(details)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(4)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 2)
                        } label: {
                            Label("Tools (\(toolExecutions.count))", systemImage: "wrench.and.screwdriver")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    private func assistantBubble(color: Color, alignment: Alignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.text.isEmpty {
                assistantContent
            }

            if isStreaming {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Working…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 700, alignment: alignment)
    }

    @ViewBuilder
    private var assistantContent: some View {
        #if canImport(Textual)
        StructuredText(markdown: message.text)
            .textual.structuredTextStyle(.gitHub)
            .textual.textSelection(.enabled)
        #else
        Text(message.text)
            .textSelection(.enabled)
        #endif
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
