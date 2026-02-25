import SwiftUI
import Foundation

private struct GitPanelError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

struct ContextPaneView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    let project: ProjectRef
    let previewResolver: ProjectPreviewResolver
    @ObservedObject var previewRuntimeManager: PreviewRuntimeManager
    let onFixLogsRequest: ((String) -> Void)?

    @State private var hasGitRepository = false
    @State private var isInitializingGit = false
    @State private var gitErrorMessage: String?

    var body: some View {
        VSplitView {
            previewPlaceholder
                .frame(minHeight: 220, idealHeight: 320)

            gitPanel
                .frame(minHeight: 180, idealHeight: 260)
        }
        .onAppear(perform: refreshGitStatus)
        .onChange(of: project.id) { _, _ in
            refreshGitStatus()
        }
        .alert("Git", isPresented: gitErrorAlertBinding) {
            Button("OK", role: .cancel) {
                gitErrorMessage = nil
            }
        } message: {
            Text(gitErrorMessage ?? "Unknown error")
        }
    }

    private var previewPlaceholder: some View {
        PreviewContextView(
            project: project,
            previewResolver: previewResolver,
            previewRuntimeManager: previewRuntimeManager,
            onFixLogsRequest: onFixLogsRequest
        )
    }

    private var gitPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Git", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.headline)

            if hasGitRepository {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You have Git initialized for this project.")
                        .fontWeight(.medium)
                    Text("Repository at \(project.localPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Text("No Git repository found")
                        .fontWeight(.medium)

                    Button {
                        Task {
                            await initializeGitRepository()
                        }
                    } label: {
                        if isInitializingGit {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Init Git", systemImage: "plus.square.on.square")
                        }
                    }
                    .disabled(isInitializingGit)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.05))
    }

    private var gitErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { gitErrorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    gitErrorMessage = nil
                }
            }
        )
    }

    private func refreshGitStatus() {
        hasGitRepository = isGitRepository(project.localPath)
    }

    private func isGitRepository(_ path: String) -> Bool {
        let gitURL = URL(fileURLWithPath: path).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitURL.path) {
            return true
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path, "rev-parse", "--is-inside-work-tree"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                return false
            }
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            return false
        }
    }

    private func initializeGitRepository() async {
        guard !isInitializingGit else { return }
        isInitializingGit = true
        defer { isInitializingGit = false }

        let result = await Task.detached(priority: .userInitiated) { () -> Result<Void, GitPanelError> in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", project.localPath, "init"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    return .success(())
                }

                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                return .failure(GitPanelError(message: output.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                return .failure(GitPanelError(message: error.localizedDescription))
            }
        }.value

        switch result {
        case .success:
            refreshGitStatus()
        case .failure(let error):
            let message = error.localizedDescription
            gitErrorMessage = message.isEmpty ? "Could not initialize Git repository." : message
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    let project = environment.shellViewModel.activeProject ?? ProjectRef(name: "Preview", localPath: "~/CopilotForgeProjects/preview")
    ContextPaneView(
        shellViewModel: environment.shellViewModel,
        project: project,
        previewResolver: environment.sharedPreviewResolver(),
        previewRuntimeManager: environment.sharedPreviewRuntimeManager(),
        onFixLogsRequest: nil
    )
}
