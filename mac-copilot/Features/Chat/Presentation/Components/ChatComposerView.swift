import SwiftUI

struct ChatComposerView: View {
    @Binding var draftPrompt: String
    @Binding var selectedModel: String
    let availableModels: [String]
    let selectedModelInfoLabel: String
    let isSending: Bool
    let onSend: () -> Void

    init(
        draftPrompt: Binding<String>,
        selectedModel: Binding<String>,
        availableModels: [String],
        selectedModelInfoLabel: String,
        isSending: Bool,
        onSend: @escaping () -> Void
    ) {
        self._draftPrompt = draftPrompt
        self._selectedModel = selectedModel
        self.availableModels = availableModels
        self.selectedModelInfoLabel = selectedModelInfoLabel
        self.isSending = isSending
        self.onSend = onSend
    }

    private var canSend: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                GrowingTextInputView(
                    text: $draftPrompt,
                    placeholder: "Ask CopilotForge to build something…",
                    minLines: 2,
                    maxLines: 8,
                    isEditable: !isSending,
                    onShiftEnter: {
                        guard canSend else { return }
                        onSend()
                    }
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
