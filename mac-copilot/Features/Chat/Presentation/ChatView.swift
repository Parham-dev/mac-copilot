import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatTranscriptView(messages: viewModel.messages)

            Divider()

            ChatComposerView(
                draftPrompt: $viewModel.draftPrompt,
                selectedModel: $viewModel.selectedModel,
                availableModels: viewModel.availableModels,
                isSending: viewModel.isSending,
                onSend: { Task { await viewModel.send() } }
            )
        }
        .navigationTitle(viewModel.chatTitle)
        .task {
            await viewModel.loadModelsIfNeeded()
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
