import Foundation
import Combine
import AppKit

@MainActor
final class ControlCenterViewModel: ObservableObject {
    let project: ProjectRef
    let runtimeManager: ControlCenterRuntimeManager

    private let resolver: ProjectControlCenterResolver
    private let onFixLogsRequest: ((String) -> Void)?
    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var resolution: ControlCenterResolution

    init(
        project: ProjectRef,
        resolver: ProjectControlCenterResolver,
        runtimeManager: ControlCenterRuntimeManager,
        onFixLogsRequest: ((String) -> Void)?
    ) {
        self.project = project
        self.resolver = resolver
        self.runtimeManager = runtimeManager
        self.onFixLogsRequest = onFixLogsRequest
        self.resolution = resolver.resolve(for: project)

        runtimeManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var activeURLText: String? {
        guard let url = runtimeManager.activeURL,
              runtimeManager.activeProjectID == project.id else {
            return nil
        }
        return url.absoluteString
    }

    var statusText: String {
        switch runtimeManager.state {
        case .idle:
            return "Idle"
        case .installing:
            return "Installing dependencies…"
        case .starting:
            return "Starting server…"
        case .running:
            return "Running"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    var adapterDisplayName: String? {
        runtimeManager.adapterName
    }

    var adapterIcon: String {
        let key = currentAdapterKey

        if key.contains("node") {
            return "terminal"
        }

        if key.contains("python") {
            return "chevron.left.forwardslash.chevron.right"
        }

        if key.contains("html") {
            return "globe"
        }

        return "shippingbox"
    }

    var canStartOrStop: Bool {
        !runtimeManager.isBusy
    }

    var canRefresh: Bool {
        !runtimeManager.isBusy && runtimeManager.activeProjectID == project.id
    }

    var canOpen: Bool {
        runtimeManager.activeURL != nil
    }

    var canRequestFix: Bool {
        onFixLogsRequest != nil && !runtimeManager.isBusy && !runtimeManager.logs.isEmpty
    }

    var canCopyLogs: Bool {
        !runtimeManager.logs.isEmpty
    }

    var logs: [String] {
        runtimeManager.logs
    }

    var shouldShowLogs: Bool {
        !runtimeManager.logs.isEmpty
    }

    func handleChatResponseDidFinish(projectPath: String) {
        guard projectPath == project.localPath else {
            return
        }

        refreshResolution()

        if runtimeManager.isRunning,
           runtimeManager.activeProjectID == project.id {
            runtimeManager.refresh(project: project)
        }
    }

    func startOrStop() {
        if runtimeManager.isRunning,
           runtimeManager.activeProjectID == project.id {
            runtimeManager.stop()
        } else {
            runtimeManager.start(project: project, autoOpen: true)
        }
    }

    func refresh() {
        runtimeManager.refresh(project: project)
    }

    func openInBrowser() {
        runtimeManager.openInBrowser()
    }

    func requestFixWithAI() {
        onFixLogsRequest?(fixPrompt)
    }

    func copyLogsToClipboard() {
        let content = runtimeManager.logs.joined(separator: "\n")
        guard !content.isEmpty else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    private func refreshResolution() {
        resolution = resolver.resolve(for: project)
    }

    private var fixPrompt: String {
        let diagnostics = runtimeManager.aiDiagnosticsSnapshot(maxEntries: 220)

        return """
        We tried to start project \(project.name) at path \(project.localPath), but control center runtime has issues.

        \(diagnostics)

        Please analyze the failure, make the required code/config fixes in this project, and then tell me to press Start again.
        """
    }

    private var currentAdapterKey: String {
        if case .ready(let launch) = resolution {
            return launch.adapterID.lowercased()
        }

        return (runtimeManager.adapterName ?? "").lowercased()
    }
}
