import SwiftUI

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
        .task {
            await viewModel.loadModelsIfNeeded()
        }
        .onChange(of: modelSelectionStore.changeToken) { _, _ in
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
        ChatView(
            viewModel: environment.chatViewModel(for: chat, project: project),
            modelSelectionStore: environment.sharedModelSelectionStore()
        )
    }
}
