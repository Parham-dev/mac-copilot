import SwiftUI

struct ShellSidebarProjectsHeaderView: View {
    let statusLabel: String
    let statusColor: Color
    let onManageCompanion: () -> Void
    let onCreateProject: () -> Void

    var body: some View {
        HStack {
            Text("Projects")
            Spacer()

            Button {
                onManageCompanion()
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Image(systemName: "iphone")
                        .foregroundStyle(.secondary)
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Mobile companion status")

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
