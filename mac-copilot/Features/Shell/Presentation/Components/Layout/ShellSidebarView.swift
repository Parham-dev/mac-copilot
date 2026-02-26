import SwiftUI

struct ShellSidebarView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    let isAuthenticated: Bool
    let onCreateProject: () -> Void
    let onOpenProject: () -> Void
    let onManageModels: () -> Void
    let onManageMCPTools: () -> Void
    let onSignOut: () -> Void

    @State private var showsUpdatePlaceholder = false
    @State private var hoveredChatID: ChatThreadRef.ID?

    var body: some View {
        GeometryReader { geometry in
            List(selection: $shellViewModel.selectedItem) {
                Section {
                    ForEach(shellViewModel.projects) { project in
                        projectDisclosure(project)
                    }
                } header: {
                    projectsHeader
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomProfileBar(sidebarWidth: geometry.size.width)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
            }
            .alert("Update", isPresented: $showsUpdatePlaceholder) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Update action placeholder. I’ll wire the real behavior next.")
            }
            .alert("Could not create chat", isPresented: chatCreationErrorAlertBinding) {
                Button("OK", role: .cancel) {
                    shellViewModel.clearChatCreationError()
                }
            } message: {
                Text(shellViewModel.chatCreationError ?? "Unknown error")
            }
        }
    }

    private var chatCreationErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { shellViewModel.chatCreationError != nil },
            set: { shouldShow in
                if !shouldShow {
                    shellViewModel.clearChatCreationError()
                }
            }
        )
    }

    private func bottomProfileBar(sidebarWidth: CGFloat) -> some View {
        ShellSidebarBottomBarView(
            isAuthenticated: isAuthenticated,
            sidebarWidth: sidebarWidth,
            onUpdate: { showsUpdatePlaceholder = true },
            onOpenProfile: { shellViewModel.selectedItem = .profile },
            onManageModels: onManageModels,
            onManageMCPTools: onManageMCPTools,
            onSignOut: onSignOut
        )
    }

    private var projectsHeader: some View {
        ShellSidebarProjectsHeaderView(
            onCreateProject: onCreateProject,
            onOpenProject: onOpenProject
        )
    }

    private func projectDisclosure(_ project: ProjectRef) -> some View {
        DisclosureGroup(isExpanded: projectExpandedBinding(for: project.id)) {
            ForEach(shellViewModel.chats(for: project.id)) { chat in
                chatRow(chat, in: project.id)
                    .tag(ShellViewModel.SidebarItem.chat(project.id, chat.id))
            }
        } label: {
            HStack(spacing: 8) {
                Label(project.name, systemImage: "folder")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        shellViewModel.selectProject(project.id)
                    }

                Spacer()

                Menu {
                    Button {
                        shellViewModel.createChat(in: project.id)
                    } label: {
                        Label("New Chat", systemImage: "plus.bubble")
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

    private func chatRow(_ chat: ChatThreadRef, in projectID: ProjectRef.ID) -> some View {
        let isActive = shellViewModel.selectedItem == .chat(projectID, chat.id)
        let showMenu = isActive || hoveredChatID == chat.id

        return HStack(spacing: 8) {
            Label(chat.title, systemImage: "bubble.left.and.bubble.right")

            Spacer(minLength: 4)

            if showMenu {
                Menu {
                    Button(role: .destructive) {
                        shellViewModel.deleteChat(chatID: chat.id, in: projectID)
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

    private func projectExpandedBinding(for projectID: UUID) -> Binding<Bool> {
        Binding(
            get: { shellViewModel.isProjectExpanded(projectID) },
            set: { shellViewModel.setProjectExpanded(projectID, isExpanded: $0) }
        )
    }
}
