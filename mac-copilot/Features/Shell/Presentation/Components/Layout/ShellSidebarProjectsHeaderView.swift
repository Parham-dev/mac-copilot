import SwiftUI

struct ShellSidebarProjectsHeaderView: View {
    let onCreateProject: () -> Void
    let onOpenProject: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        HStack {
            Text("Projects")
            Spacer()

            Button("Update") {
                onCheckForUpdates()
            }
            .buttonStyle(.borderless)
            .help("Check for app updates")

            Menu {
                Button {
                    onCreateProject()
                } label: {
                    Label("New Project", systemImage: "folder.badge.plus")
                }

                Button {
                    onOpenProject()
                } label: {
                    Label("Open Project", systemImage: "folder")
                }
            } label: {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .center)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .padding(.trailing, 4)
            .help("New Project or Open Project")
        }
    }
}
