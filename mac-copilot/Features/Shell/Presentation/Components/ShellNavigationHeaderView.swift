import SwiftUI
import AppKit

private func openProjectInTarget(projectURL: URL, target: OpenTarget) {
    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.open([projectURL], withApplicationAt: target.appURL, configuration: configuration) { _, _ in }
}

struct ShellOpenProjectMenuButton: View {
    @ObservedObject var shellViewModel: ShellViewModel

    private var state: ShellNavigationHeaderState {
        ShellNavigationHeaderState(shellViewModel: shellViewModel)
    }

    var body: some View {
        if let projectURL = state.currentProjectURL, !state.availableOpenTargets.isEmpty {
            Menu {
                ForEach(state.availableOpenTargets) { target in
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
}

@MainActor
struct ShellNavigationHeaderState {
    private let headerContext: HeaderContext

    init(shellViewModel: ShellViewModel) {
        guard let selectedItem = shellViewModel.selectedItem else {
            self.headerContext = .app
            return
        }

        switch selectedItem {
        case .profile:
            self.headerContext = .profile
        case .chat(let projectID, _):
            guard let project = shellViewModel.project(for: projectID) else {
                self.headerContext = .app
                return
            }
            self.headerContext = .project(project)
        }
    }

    var title: String {
        switch headerContext {
        case .app:
            return "CopilotForge"
        case .profile:
            return "Profile"
        case .project(let project):
            return project.name
        }
    }

    var currentProjectURL: URL? {
        switch headerContext {
        case .project(let project):
            return URL(fileURLWithPath: project.localPath, isDirectory: true)
        case .app, .profile:
            return nil
        }
    }

    var availableOpenTargets: [OpenTarget] {
        guard currentProjectURL != nil else {
            return []
        }

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

            guard !seenPaths.contains(appURL.path) else {
                continue
            }

            seenPaths.insert(appURL.path)
            targets.append(OpenTarget(appURL: appURL))
        }

        let preferredEditorAppNames = [
            "Windsurf",
            "Nova",
            "Antigravity"
        ]

        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        for appName in preferredEditorAppNames {
            for directory in searchDirectories {
                let appURL = directory.appendingPathComponent("\(appName).app", isDirectory: true)
                guard FileManager.default.fileExists(atPath: appURL.path) else {
                    continue
                }

                guard !seenPaths.contains(appURL.path) else {
                    continue
                }

                seenPaths.insert(appURL.path)
                targets.append(OpenTarget(appURL: appURL))
            }
        }

        return targets
    }
}

private enum HeaderContext {
    case app
    case profile
    case project(ProjectRef)
}

struct OpenTarget: Identifiable {
    let appURL: URL
    let displayName: String
    let icon: NSImage

    var id: String {
        appURL.path
    }

    init(appURL: URL) {
        self.appURL = appURL
        self.displayName = FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: "")
        self.icon = NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
