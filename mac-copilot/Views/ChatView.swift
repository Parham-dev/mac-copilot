import SwiftUI

struct ChatView: View {
    let chatTitle: String

    private let copilotService = CopilotAPIService()

    @State private var draftPrompt = ""
    @State private var isSending = false
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hi! Describe the app you want to build."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
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
                TextField("Ask CopilotForge to build something…", text: $draftPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                Button("Send") {
                    Task { await send() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle(chatTitle)
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

    private func send() async {
        let text = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard !isSending else { return }

        isSending = true

        messages.append(ChatMessage(role: .user, text: text))
        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, text: ""))
        draftPrompt = ""

        do {
            var hasContent = false
            for try await chunk in copilotService.streamPrompt(text) {
                hasContent = true
                messages[assistantIndex].text += chunk
            }

            if !hasContent {
                messages[assistantIndex].text = "No response from Copilot."
            }
        } catch {
            messages[assistantIndex].text = "Error: \(error.localizedDescription)"
        }

        isSending = false
    }
}

#Preview {
    NavigationStack {
        ChatView(chatTitle: "New Project")
    }
}
