import SwiftUI
import AppKit

private extension NSFont {
    var composerLineHeight: CGFloat {
        ascender - descender + leading
    }
}

struct ChatComposerView: View {
    @Binding var draftPrompt: String
    @Binding var selectedModel: String
    let availableModels: [String]
    let selectedModelInfoLabel: String
    let isSending: Bool
    let onSend: () -> Void

    @State private var composerHeight: CGFloat = 56

    private var canSend: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private var minComposerHeight: CGFloat {
        let lineHeight = NSFont.preferredFont(forTextStyle: .body).composerLineHeight
        return ceil((lineHeight * 2) + 14)
    }

    private var maxComposerHeight: CGFloat {
        let lineHeight = NSFont.preferredFont(forTextStyle: .body).composerLineHeight
        return ceil((lineHeight * 8) + 14)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if draftPrompt.isEmpty {
                        Text("Ask CopilotForge to build something…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }

                    ComposerTextView(
                        text: $draftPrompt,
                        dynamicHeight: $composerHeight,
                        minHeight: minComposerHeight,
                        maxHeight: maxComposerHeight,
                        isEditable: !isSending,
                        onShiftEnter: {
                            guard canSend else { return }
                            onSend()
                        }
                    )
                    .frame(height: composerHeight)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )

                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .disabled(!canSend)
            }

            HStack {
                ChatToolbarControlsView(
                    selectedModel: $selectedModel,
                    availableModels: availableModels,
                    selectedModelInfoLabel: selectedModelInfoLabel
                )
                Spacer()
                Text(isSending ? "Generating…" : "Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
