import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
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
        .navigationTitle(viewModel.chatTitle)
        .task {
            await viewModel.loadModelsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelSelectionPreferences.didChangeNotification)) { _ in
            Task {
                await viewModel.loadModelsIfNeeded(forceReload: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        let environment = AppEnvironment.preview()
        let project = environment.shellViewModel.activeProject ?? ProjectRef(name: "Preview", localPath: "~/CopilotForgeProjects/preview")
        let chat = environment.shellViewModel.chats(for: project.id).first ?? ChatThreadRef(projectID: project.id, title: "General")
        ChatView(viewModel: environment.chatViewModel(for: chat, project: project))
    }
}
