import SwiftUI

struct ShellDetailPaneView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    @ObservedObject var shellEnvironment: ShellEnvironment
    let isAuthenticated: Bool

    var body: some View {
        if !isAuthenticated {
            AuthView()
        } else if let selectedItem = shellViewModel.selectedItem {
            switch selectedItem {
            case .profile:
                ProfileView(viewModel: shellEnvironment.profileViewModel)
            case .chat(let projectID, let selectedChatID):
                chatDetailContent(projectID: projectID, selectedChatID: selectedChatID)
            }
        } else {
            ContentUnavailableView("Select a chat", systemImage: "message")
        }
    }

    @ViewBuilder
    private func chatDetailContent(projectID: UUID, selectedChatID: UUID) -> some View {
        if let activeProject = shellViewModel.project(for: projectID),
           let selectedChat = shellViewModel.chat(for: selectedChatID, in: projectID) {
            let chatViewModel = shellEnvironment.chatViewModel(for: selectedChat, project: activeProject)

            HSplitView {
                ChatView(
                    viewModel: chatViewModel,
                    modelSelectionStore: shellEnvironment.modelSelectionStore
                )
                    .frame(minWidth: 380, idealWidth: 540)
                    .layoutPriority(2)

                ContextPaneView(
                    shellViewModel: shellViewModel,
                    project: activeProject,
                    controlCenterResolver: shellEnvironment.controlCenterResolver,
                    controlCenterRuntimeManager: shellEnvironment.controlCenterRuntimeManager,
                    viewModel: shellEnvironment.makeContextPaneViewModel(),
                    chatEventsStore: shellEnvironment.chatEventsStore,
                    onFixLogsRequest: { prompt in
                        Task {
                            await chatViewModel.send(prompt: prompt)
                        }
                    }
                )
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 340)
                .layoutPriority(1)
            }
        } else if shellViewModel.project(for: projectID) == nil {
            ContentUnavailableView("Select a project", systemImage: "folder")
        } else {
            ContentUnavailableView("Select a chat", systemImage: "message")
        }
    }
}