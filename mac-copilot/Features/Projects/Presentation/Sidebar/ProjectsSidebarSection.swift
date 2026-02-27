import SwiftUI

/// Sidebar content for the Projects feature.
///
/// Renders the projects + chats disclosure tree inside the shell's unified
/// `List(selection:)`. Chat rows use `.tag(AnyHashable(...))` so the List
/// handles highlighting. The `selection` binding is the shell-level unified
/// `AnyHashable?` list selection — when a row is tagged and selected, the
/// binding is set automatically by SwiftUI's List machinery.
///
/// The `selection` binding's `set` side is connected to
/// `ShellViewModel.selectionBinding(for: "projects")` so that
/// `ShellViewModel.selectionByFeature["projects"]` stays current.
///
/// VM sync (shell → ProjectsViewModel) is handled centrally in ContentView
/// via `onReceive(shellViewModel.$selectionByFeature)` to avoid relying on
/// `onChange` inside an `AnyView`-wrapped section, which is unreliable.
struct ProjectsSidebarSection: View {
    @EnvironmentObject private var projectsEnvironment: ProjectsEnvironment

    /// Shell-level unified list selection binding.
    @Binding var selection: AnyHashable?

    @State private var hoveredChatID: ChatThreadRef.ID?

    // MARK: - Decoded selection

    private var selectedChatItem: ProjectsViewModel.SidebarItem? {
        selection as? ProjectsViewModel.SidebarItem
    }

    // MARK: - Body

    var body: some View {
        let vm = projectsEnvironment.projectsViewModel

        ForEach(vm.projects) { project in
            projectDisclosure(project, vm: vm)
        }
    }

    // MARK: - Project row

    private func projectDisclosure(_ project: ProjectRef, vm: ProjectsViewModel) -> some View {
        DisclosureGroup(isExpanded: expandedBinding(for: project.id, vm: vm)) {
            ForEach(vm.chats(for: project.id)) { chat in
                chatRow(chat, in: project.id, vm: vm)
                    .tag(AnyHashable(ProjectsViewModel.SidebarItem.chat(project.id, chat.id)))
            }
        } label: {
            HStack(spacing: 8) {
                Label(project.name, systemImage: "folder")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.selectProject(project.id)
                        // Select first chat when tapping the project row.
                        if let firstChat = vm.chats(for: project.id).first {
                            let item = ProjectsViewModel.SidebarItem.chat(project.id, firstChat.id)
                            selection = AnyHashable(item)
                        }
                    }

                Spacer()

                Menu {
                    Button {
                        vm.createChat(in: project.id)
                        // After creation, vm.selectedItem is updated; mirror to list.
                        if let newItem = vm.selectedItem {
                            selection = AnyHashable(newItem)
                        }
                    } label: {
                        Label("New Chat", systemImage: "plus.bubble")
                    }

                    Button(role: .destructive) {
                        vm.deleteProject(projectID: project.id)
                        projectsEnvironment.evictContextPaneViewModel(for: project.id)
                        if let newItem = vm.selectedItem {
                            selection = AnyHashable(newItem)
                        } else {
                            selection = nil
                        }
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .symbolRenderingMode(.monochrome)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 18, alignment: .center)
                        .tint(.primary)
                }
                .menuIndicator(.hidden)
                .menuStyle(.borderlessButton)
            }
        }
    }

    // MARK: - Chat row

    private func chatRow(_ chat: ChatThreadRef, in projectID: ProjectRef.ID, vm: ProjectsViewModel) -> some View {
        let isActive = selectedChatItem == .chat(projectID, chat.id)
        let showMenu = isActive || hoveredChatID == chat.id

        return HStack(spacing: 8) {
            Label(chat.title, systemImage: "bubble.left.and.bubble.right")

            Spacer(minLength: 4)

            if showMenu {
                Menu {
                    Button(role: .destructive) {
                        vm.deleteChat(chatID: chat.id, in: projectID)
                        // Mirror replacement selection.
                        if let newItem = vm.selectedItem {
                            selection = AnyHashable(newItem)
                        } else {
                            selection = nil
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .symbolRenderingMode(.monochrome)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 18, alignment: .center)
                        .tint(.primary)
                }
                .menuIndicator(.hidden)
                .menuStyle(.borderlessButton)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering {
                hoveredChatID = chat.id
            } else if hoveredChatID == chat.id {
                hoveredChatID = nil
            }
        }
    }

    // MARK: - Helpers

    private func expandedBinding(for projectID: UUID, vm: ProjectsViewModel) -> Binding<Bool> {
        Binding(
            get: { vm.isProjectExpanded(projectID) },
            set: { vm.setProjectExpanded(projectID, isExpanded: $0) }
        )
    }
}
