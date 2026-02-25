import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        HStack {
                            if message.role == .assistant {
                                bubble(for: message, color: .gray.opacity(0.2), alignment: .leading)
                                Spacer(minLength: 40)
                            } else {
                                Spacer(minLength: 40)
                                bubble(for: message, color: .accentColor.opacity(0.2), alignment: .trailing)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Ask CopilotForge to build something…", text: $viewModel.draftPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                Button("Send") {
                    Task { await viewModel.send() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding()
        }
        .navigationTitle(viewModel.chatTitle)
    }

    @ViewBuilder
    private func bubble(for message: ChatMessage, color: Color, alignment: Alignment) -> some View {
        Text(message.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: 600, alignment: alignment)
    }
}

#Preview {
    NavigationStack {
        ChatView(viewModel: AppEnvironment.preview().chatViewModel(for: "New Project"))
    }
}
