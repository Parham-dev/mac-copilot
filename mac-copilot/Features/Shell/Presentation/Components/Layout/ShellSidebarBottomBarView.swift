import SwiftUI

struct ShellSidebarBottomBarView: View {
    let isAuthenticated: Bool
    let sidebarWidth: CGFloat
    let onOpenProfile: () -> Void
    let companionStatusLabel: String
    let isUpdateAvailable: Bool
    let onCheckForUpdates: () -> Void
    let onManageCompanion: () -> Void
    let onManageModels: () -> Void
    let onManageMCPTools: () -> Void
    let onSignOut: () -> Void

    @State private var showsProfileMenu = false

    var body: some View {
        if isUpdateAvailable {
            // 2/3 settings + 1/3 update — use GeometryReader for true proportional widths.
            GeometryReader { geo in
                let spacing: CGFloat = 6
                let updateWidth = (geo.size.width - spacing) / 3
                let settingsWidth = geo.size.width - spacing - updateWidth

                HStack(spacing: spacing) {
                    settingsButton
                        .frame(width: settingsWidth)
                    updateButton
                        .frame(width: updateWidth)
                }
            }
            .frame(height: 36)
        } else {
            settingsButton
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button {
            showsProfileMenu.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("Settings")
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsProfileMenu, arrowEdge: .bottom) {
            profileMenuContent
        }
    }

    // MARK: - Update Button

    private var updateButton: some View {
        Button {
            onCheckForUpdates()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.body)
                    .foregroundStyle(.tint)
                Text("Update")
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("An update is available — click to install")
    }

    // MARK: - Profile Menu

    private var profileMenuContent: some View {
        let popoverWidth = max(200, sidebarWidth - 24)

        return VStack(alignment: .leading, spacing: 6) {
            profileMenuButton("Profile", systemImage: "person.crop.circle") {
                onOpenProfile()
                showsProfileMenu = false
            }

            profileMenuButton("Mobile Companion (\(companionStatusLabel))", systemImage: "iphone") {
                onManageCompanion()
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
    private func profileMenuButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
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
