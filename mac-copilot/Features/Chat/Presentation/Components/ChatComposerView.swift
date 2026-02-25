import SwiftUI

struct ChatComposerView: View {
    @Binding var draftPrompt: String
    @Binding var selectedModel: String
    let availableModels: [String]
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask CopilotForge to build something…", text: $draftPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...8)

                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }

            HStack {
                ChatToolbarControlsView(selectedModel: $selectedModel, availableModels: availableModels)
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
