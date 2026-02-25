import SwiftUI

struct ShellSidebarBottomBarView: View {
    let isAuthenticated: Bool
    let sidebarWidth: CGFloat
    let onUpdate: () -> Void
    let onOpenProfile: () -> Void
    let onManageModels: () -> Void
    let onManageMCPTools: () -> Void
    let onSignOut: () -> Void

    @State private var showsProfileMenu = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onUpdate()
            } label: {
                Text("Update")
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                showsProfileMenu.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Settings")
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showsProfileMenu, arrowEdge: .bottom) {
                profileMenuContent
            }
        }
    }

    private var profileMenuContent: some View {
        let popoverWidth = max(220, sidebarWidth - 24)

        return VStack(alignment: .leading, spacing: 6) {
            profileMenuButton("Profile", systemImage: "person.crop.circle") {
                onOpenProfile()
                showsProfileMenu = false
            }

            profileMenuButton("Models", systemImage: "slider.horizontal.3") {
                onManageModels()
                showsProfileMenu = false
            }

            profileMenuButton("MCP Tools", systemImage: "wrench.and.screwdriver") {
                onManageMCPTools()
                showsProfileMenu = false
            }

            if isAuthenticated {
                Divider()
                profileMenuButton("Log Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    onSignOut()
                    showsProfileMenu = false
                }
            }
        }
        .padding(10)
        .frame(width: popoverWidth, alignment: .leading)
    }

    @ViewBuilder
    private func profileMenuButton(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
