import SwiftUI
#if DEBUG
import AppKit
#endif

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var modelSelectionStore: ModelSelectionStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "message")
                    .font(.title3)
                Text(viewModel.chatTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
#if DEBUG
                Button {
                    copyDebugContext()
                } label: {
                    Label("Copy Debug", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
#endif
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            ChatTranscriptView(
                messages: viewModel.messages,
                statusChipsByMessageID: viewModel.statusChipsByMessageID,
                toolExecutionsByMessageID: viewModel.toolExecutionsByMessageID,
                streamingAssistantMessageID: viewModel.streamingAssistantMessageID
            )

            Divider()

            ChatComposerView(
                draftPrompt: $viewModel.draftPrompt,
                selectedModel: $viewModel.selectedModel,
                availableModels: viewModel.availableModels,
                selectedModelInfoLabel: viewModel.selectedModelInfoLabel,
                isSending: viewModel.isSending,
                onSend: { Task { await viewModel.send() } }
            )
        }
        .task(id: viewModel.chatID) {
            await viewModel.loadModelsIfNeeded()
        }
        .onChange(of: modelSelectionStore.changeToken) { _, _ in
            Task {
                await viewModel.loadModelsIfNeeded(forceReload: true)
            }
        }
    }
}

#if DEBUG
private extension ChatView {
    func copyDebugContext() {
        let enabledTools = viewModel.mcpToolsStore.enabledToolIDs()
        let resolvedTools = enabledTools.isEmpty ? ["<all-tools-enabled>"] : enabledTools

        let payload = [
            "chatID=\(viewModel.chatID.uuidString)",
            "chatTitle=\(viewModel.chatTitle)",
            "projectPath=\(viewModel.projectPath)",
            "selectedModel=\(viewModel.selectedModel)",
            "enabledTools=\(resolvedTools.joined(separator: ","))",
            "streamingAssistantMessageID=\(viewModel.streamingAssistantMessageID?.uuidString ?? "nil")",
            "messageCount=\(viewModel.messages.count)",
            "timestamp=\(ISO8601DateFormatter().string(from: Date()))"
        ].joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
    }
}
#endif

#Preview {
    NavigationStack {
        let environment = AppEnvironment.preview()
        let shellEnvironment = environment.shellEnvironment
        let project = shellEnvironment.shellViewModel.activeProject ?? ProjectRef(name: "Preview", localPath: "~/CopilotForgeProjects/preview")
        let chat = shellEnvironment.shellViewModel.chats(for: project.id).first ?? ChatThreadRef(projectID: project.id, title: "General")
        ChatView(
            viewModel: shellEnvironment.chatViewModel(for: chat, project: project),
            modelSelectionStore: shellEnvironment.modelSelectionStore
        )
    }
}
