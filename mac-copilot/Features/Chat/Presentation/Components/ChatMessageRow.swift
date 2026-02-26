import SwiftUI
import AppKit
#if canImport(Textual)
import Textual
#endif

struct ChatMessageRow: View {
    let message: ChatMessage
    let isStreaming: Bool
    let inlineSegments: [AssistantTranscriptSegment]

    @State private var expandedToolIDs: Set<UUID> = []

    var body: some View {
        HStack {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 6) {
                    assistantBubble(color: .gray.opacity(0.18), alignment: .leading)

                    if !message.text.isEmpty {
                        Button {
                            copyToClipboard(fullCopyText)
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
            if !inlineSegments.isEmpty {
                assistantInlineContent
            } else if !message.text.isEmpty {
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
            .textual.textSelection(.disabled)
        #else
        Text(message.text)
            .textSelection(.enabled)
        #endif
    }

    private var assistantInlineContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(inlineSegments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let text):
                    if !text.isEmpty {
                        #if canImport(Textual)
                        StructuredText(markdown: text)
                            .textual.structuredTextStyle(.gitHub)
                            .textual.textSelection(.disabled)
                        #else
                        Text(text)
                            .textSelection(.enabled)
                        #endif
                    }
                case .tool(let tool):
                    toolCallCard(tool)
                }
            }
        }
    }

    private func toolCallCard(_ tool: ChatMessage.ToolExecution) -> some View {
        DisclosureGroup(isExpanded: bindingForTool(tool.id)) {
            VStack(alignment: .leading, spacing: 10) {
                detailSection(title: "Input", value: normalizedValue(tool.input))
                detailSection(title: "Output", value: normalizedValue(resolvedOutput(for: tool)))
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.toolName)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(toolSubtitle(for: tool))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: tool.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(tool.success ? .green : .red)
            }
        }
        .tint(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.gray.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func detailSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func toolSubtitle(for tool: ChatMessage.ToolExecution) -> String {
        let output = resolvedOutput(for: tool)
        if !output.isEmpty {
            return leadingWords(from: output, limit: 8)
        }

        return tool.success ? "No output" : "Failed"
    }

    private func resolvedOutput(for tool: ChatMessage.ToolExecution) -> String {
        if let output = tool.output?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            return output
        }

        if let details = tool.details?.trimmingCharacters(in: .whitespacesAndNewlines), !details.isEmpty {
            return details
        }

        return ""
    }

    private func normalizedValue(_ raw: String?) -> String {
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "Not provided" : text
    }

    private func leadingWords(from text: String, limit: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        let words = normalized.split(separator: " ")
        if words.count <= limit {
            return normalized
        }

        return words.prefix(limit).joined(separator: " ") + "…"
    }

    private func bindingForTool(_ toolID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedToolIDs.contains(toolID) },
            set: { isExpanded in
                if isExpanded {
                    expandedToolIDs.insert(toolID)
                } else {
                    expandedToolIDs.remove(toolID)
                }
            }
        )
    }

    private func bubble(color: Color, alignment: Alignment) -> some View {
        Text(message.text)
            .textSelection(.enabled)
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

    private var fullCopyText: String {
        if inlineSegments.isEmpty {
            return message.text
        }

        let parts = inlineSegments.compactMap { segment -> String? in
            switch segment {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            case .tool(let tool):
                var lines: [String] = []
                lines.append("Tool: \(tool.toolName) [\(tool.success ? "success" : "failed")]")
                lines.append("Input:\n\(normalizedValue(tool.input))")
                lines.append("Output:\n\(normalizedValue(resolvedOutput(for: tool)))")
                return lines.joined(separator: "\n")
            }
        }

        return parts.joined(separator: "\n\n")
    }
}
