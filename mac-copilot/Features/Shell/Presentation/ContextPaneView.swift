import SwiftUI
import Foundation

struct ContextPaneView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    let project: ProjectRef
    let previewResolver: ProjectPreviewResolver
    @ObservedObject var previewRuntimeManager: PreviewRuntimeManager
    private let checkGitRepositoryUseCase: CheckGitRepositoryUseCase
    private let initializeGitRepositoryUseCase: InitializeGitRepositoryUseCase
    let onFixLogsRequest: ((String) -> Void)?

    @State private var hasGitRepository = false
    @State private var isInitializingGit = false
    @State private var gitErrorMessage: String?

    init(
        shellViewModel: ShellViewModel,
        project: ProjectRef,
        previewResolver: ProjectPreviewResolver,
        previewRuntimeManager: PreviewRuntimeManager,
        gitRepositoryManager: GitRepositoryManaging,
        onFixLogsRequest: ((String) -> Void)?
    ) {
        self.shellViewModel = shellViewModel
        self.project = project
        self.previewResolver = previewResolver
        self.previewRuntimeManager = previewRuntimeManager
        self.onFixLogsRequest = onFixLogsRequest
        self.checkGitRepositoryUseCase = CheckGitRepositoryUseCase(repositoryManager: gitRepositoryManager)
        self.initializeGitRepositoryUseCase = InitializeGitRepositoryUseCase(repositoryManager: gitRepositoryManager)
    }

    var body: some View {
        VSplitView {
            previewPlaceholder
                .frame(minHeight: 220, idealHeight: 320)

            gitPanel
                .frame(minHeight: 180, idealHeight: 260)
        }
        .onAppear {
            Task {
                await refreshGitStatus()
            }
        }
        .onChange(of: project.id) { _, _ in
            Task {
                await refreshGitStatus()
            }
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
            panelTitle("Git", systemImage: "point.topleft.down.curvedto.point.bottomright.up")

            if hasGitRepository {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You have Git initialized for this project.")
                        .font(.body)
                    Text("Repository at \(project.localPath)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Text("No Git repository found")
                        .font(.body)

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

    private func panelTitle(_ title: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
        }
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

    private func refreshGitStatus() async {
        hasGitRepository = await checkGitRepositoryUseCase.execute(path: project.localPath)
    }

    private func initializeGitRepository() async {
        guard !isInitializingGit else { return }
        isInitializingGit = true
        defer { isInitializingGit = false }

        do {
            try await initializeGitRepositoryUseCase.execute(path: project.localPath)
            await refreshGitStatus()
        } catch {
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
        gitRepositoryManager: environment.sharedGitRepositoryManager(),
        onFixLogsRequest: nil
    )
}
