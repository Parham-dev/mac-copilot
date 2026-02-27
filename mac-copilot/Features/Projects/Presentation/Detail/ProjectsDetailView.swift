import SwiftUI

/// Detail pane for the Projects feature.
///
/// Decodes the shell-level `AnyHashable?` selection back into
/// `ProjectsViewModel.SidebarItem` and renders either a chat split-view
/// or an appropriate empty-state placeholder.
struct ProjectsDetailView: View {
    @EnvironmentObject private var projectsEnvironment: ProjectsEnvironment
    @EnvironmentObject private var authViewModel: AuthViewModel
    /// Shell-level opaque selection value for this feature.
    let selection: AnyHashable?

    var body: some View {
        if !authViewModel.isAuthenticated {
            AuthView()
        } else if let item = selection as? ProjectsViewModel.SidebarItem {
            switch item {
            case .chat(let projectID, let chatID):
                chatDetail(projectID: projectID, chatID: chatID)
            }
        } else {
            ContentUnavailableView("Select a chat", systemImage: "message")
        }
    }

    // MARK: - Chat detail

    @ViewBuilder
    private func chatDetail(projectID: UUID, chatID: UUID) -> some View {
        let vm = projectsEnvironment.projectsViewModel

        if let project = vm.project(for: projectID),
           let chat = vm.chat(for: chatID, in: projectID) {
            let chatViewModel = projectsEnvironment.chatViewModel(for: chat, project: project)
            let item = ProjectsViewModel.SidebarItem.chat(projectID, chatID)

            HSplitView {
                ChatView(
                    viewModel: chatViewModel,
                    modelSelectionStore: projectsEnvironment.modelSelectionStore
                )
                .frame(minWidth: 380, idealWidth: 540)
                .layoutPriority(2)

                ContextPaneView(
                    projectsViewModel: vm,
                    project: project,
                    controlCenterResolver: projectsEnvironment.controlCenterResolver,
                    controlCenterRuntimeManager: projectsEnvironment.controlCenterRuntimeManager,
                    viewModel: projectsEnvironment.contextPaneViewModel(for: projectID),
                    chatEventsStore: projectsEnvironment.chatEventsStore,
                    onFixLogsRequest: { prompt in
                        Task {
                            await chatViewModel.send(prompt: prompt)
                        }
                    }
                )
                // Force ContextPaneView teardown when the project changes so its
                // @StateObject picks up the correct cached ContextPaneViewModel.
                .id(projectID)
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 340)
                .layoutPriority(1)
            }
            // Notify ProjectsViewModel of the active item so it can update
            // activeProjectID and expand the disclosure group. selectedItem
            // itself is kept in sync via ContentView's onReceive($selectedItem)
            // in the other direction (VM → shell), so we only call didSelectItem
            // here to trigger the expansion side-effect, not to set selectedItem.
            .onAppear { vm.didSelectItem(item) }
            .onChange(of: item) { _, newItem in vm.didSelectItem(newItem) }
        } else if vm.project(for: projectID) == nil {
            ContentUnavailableView("Select a project", systemImage: "folder")
        } else {
            ContentUnavailableView("Select a chat", systemImage: "message")
        }
    }
}
