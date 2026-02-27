import SwiftUI
import AppKit

private func openProjectInTarget(projectURL: URL, target: OpenTarget) {
    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.open([projectURL], withApplicationAt: target.appURL, configuration: configuration) { _, _ in }
}

/// Sidebar section menu button for project actions.
///
/// Shows only project CRUD actions and is intended for the Projects section
/// header in the sidebar.
struct ProjectsSectionActionMenuButton: View {
    @ObservedObject var projectsViewModel: ProjectsViewModel
    let projectCreationService: ProjectCreationService
    let iconSystemName: String

    @State private var actionErrorMessage: String?

    var body: some View {
        Menu {
            Button {
                createNewProject()
            } label: {
                Label("Create New Project", systemImage: "folder.badge.plus")
            }

            Button {
                openExistingProject()
            } label: {
                Label("Open Existing Project", systemImage: "folder")
            }
        } label: {
            Image(systemName: iconSystemName)
                .symbolRenderingMode(.hierarchical)
        }
        .menuStyle(.borderlessButton)
        .help("Project actions")
        .alert("Project Action Failed", isPresented: actionErrorBinding) {
            Button("OK", role: .cancel) { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "Could not complete project action.")
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )
    }

    // MARK: - Project actions

    private func createNewProject() {
        do {
            guard let created = try projectCreationService.createProjectInteractively() else { return }
            _ = try projectsViewModel.addProject(name: created.name, localPath: created.localPath)
        } catch {
            actionErrorMessage = UserFacingErrorMapper.message(
                error,
                fallback: "Could not create project right now."
            )
        }
    }

    private func openExistingProject() {
        do {
            guard let selected = try projectCreationService.openProjectInteractively() else { return }
            _ = try projectsViewModel.addProject(name: selected.name, localPath: selected.localPath)
        } catch {
            actionErrorMessage = UserFacingErrorMapper.message(
                error,
                fallback: "Could not open project right now."
            )
        }
    }
}

/// Toolbar button that offers "Open In: <editor>" for the active project.
///
/// Intended for the navigation header (top bar) and shown only when Projects
/// is the active feature.
struct ShellOpenProjectMenuButton: View {
    @ObservedObject var projectsViewModel: ProjectsViewModel

    var body: some View {
        if let projectURL = currentProjectURL, !availableOpenTargets.isEmpty {
            Menu {
                ForEach(availableOpenTargets) { target in
                    Button {
                        openProjectInTarget(projectURL: projectURL, target: target)
                    } label: {
                        Label {
                            Text(target.displayName)
                        } icon: {
                            Image(nsImage: target.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    Spacer(minLength: 14)
                    Text("Open In:")
                    Spacer(minLength: 14)
                }
                .frame(minWidth: 128)
            }
            .controlSize(.large)
            .menuStyle(.borderlessButton)
            .help("Open current project in a code editor")
        }
    }

    // MARK: - Derived state

    private var currentProjectURL: URL? {
        guard let project = projectsViewModel.activeProject else { return nil }
        return URL(fileURLWithPath: project.localPath, isDirectory: true)
    }

    private var availableOpenTargets: [OpenTarget] {
        guard currentProjectURL != nil else { return [] }

        var targets: [OpenTarget] = []
        var seenPaths = Set<String>()

        let preferredEditorBundleIDs = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.todesktop.230313mzl4w4u92",
            "com.apple.dt.Xcode",
            "com.google.android.studio",
            "com.vscodium",
            "com.codeium.windsurf",
            "com.exafunction.windsurf",
            "com.panic.Nova",
            "com.antigravity.app",
            "com.jetbrains.intellij",
            "com.jetbrains.pycharm",
            "com.jetbrains.WebStorm",
            "com.jetbrains.CLion",
            "com.jetbrains.RubyMine",
            "com.jetbrains.DataGrip",
            "com.jetbrains.GoLand",
            "com.jetbrains.rider"
        ]

        for bundleID in preferredEditorBundleIDs {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                continue
            }
            guard !seenPaths.contains(appURL.path) else { continue }
            seenPaths.insert(appURL.path)
            targets.append(OpenTarget(appURL: appURL))
        }

        let preferredEditorAppNames = ["Windsurf", "Nova", "Antigravity"]
        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        for appName in preferredEditorAppNames {
            for directory in searchDirectories {
                let appURL = directory.appendingPathComponent("\(appName).app", isDirectory: true)
                guard FileManager.default.fileExists(atPath: appURL.path) else { continue }
                guard !seenPaths.contains(appURL.path) else { continue }
                seenPaths.insert(appURL.path)
                targets.append(OpenTarget(appURL: appURL))
            }
        }

        return targets
    }
}

// MARK: - OpenTarget

struct OpenTarget: Identifiable {
    let appURL: URL
    let displayName: String
    let icon: NSImage

    var id: String { appURL.path }

    init(appURL: URL) {
        self.appURL = appURL
        self.displayName = FileManager.default.displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
        self.icon = NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
