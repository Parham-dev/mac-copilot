import SwiftUI

struct ShellSidebarView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    let isAuthenticated: Bool
    let onCreateProject: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        List(selection: $shellViewModel.selectedItem) {
            Section("Workspace") {
                Label("Profile", systemImage: "person.crop.circle")
                    .tag(ShellViewModel.SidebarItem.profile)
            }

            Section {
                ForEach(shellViewModel.projects) { project in
                    projectDisclosure(project)
                }
            } header: {
                projectsHeader
            }

            if isAuthenticated {
                Section {
                    Button {
                        onSignOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }

    private var projectsHeader: some View {
        HStack {
            Text("Projects")
            Spacer()
            Button {
                onCreateProject()
            } label: {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .center)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            .help("Add New Project")
        }
    }

    private func projectDisclosure(_ project: ProjectRef) -> some View {
        DisclosureGroup(isExpanded: projectExpandedBinding(for: project.id)) {
            ForEach(shellViewModel.chats(for: project.id)) { chat in
                Label(chat.title, systemImage: "bubble.left.and.bubble.right")
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
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .center)
                }
                .menuIndicator(.hidden)
                .menuStyle(.borderlessButton)

                if shellViewModel.activeProjectID == project.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                }
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