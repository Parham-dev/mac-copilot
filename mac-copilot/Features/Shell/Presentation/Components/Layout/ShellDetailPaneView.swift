import SwiftUI

struct ShellDetailPaneView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    @ObservedObject var appEnvironment: AppEnvironment
    let isAuthenticated: Bool

    var body: some View {
        if !isAuthenticated {
            AuthView()
        } else if let selectedItem = shellViewModel.selectedItem {
            switch selectedItem {
            case .profile:
                ProfileView(viewModel: appEnvironment.profileViewModel)
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
            let chatViewModel = appEnvironment.chatViewModel(for: selectedChat, project: activeProject)

            HSplitView {
                ChatView(
                    viewModel: chatViewModel,
                    modelSelectionStore: appEnvironment.modelSelectionStore
                )
                    .frame(minWidth: 300, idealWidth: 470)

                ContextPaneView(
                    shellViewModel: shellViewModel,
                    project: activeProject,
                    controlCenterResolver: appEnvironment.controlCenterResolver,
                    controlCenterRuntimeManager: appEnvironment.controlCenterRuntimeManager,
                    gitRepositoryManager: appEnvironment.gitRepositoryManager,
                    onFixLogsRequest: { prompt in
                        Task {
                            await chatViewModel.send(prompt: prompt)
                        }
                    }
                )
                .frame(minWidth: 300, idealWidth: 470)
            }
        } else if shellViewModel.project(for: projectID) == nil {
            ContentUnavailableView("Select a project", systemImage: "folder")
        } else {
            ContentUnavailableView("Select a chat", systemImage: "message")
        }
    }
}