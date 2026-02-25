import SwiftUI

struct ShellSidebarProjectsHeaderView: View {
    let onCreateProject: () -> Void

    var body: some View {
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
}
