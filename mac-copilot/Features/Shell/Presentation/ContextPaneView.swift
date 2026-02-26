import SwiftUI
import Foundation
import Combine

struct ContextPaneView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    let project: ProjectRef
    let controlCenterResolver: ProjectControlCenterResolver
    @ObservedObject var controlCenterRuntimeManager: ControlCenterRuntimeManager
    @StateObject private var viewModel: ContextPaneViewModel
    let onFixLogsRequest: ((String) -> Void)?

    init(
        shellViewModel: ShellViewModel,
        project: ProjectRef,
        controlCenterResolver: ProjectControlCenterResolver,
        controlCenterRuntimeManager: ControlCenterRuntimeManager,
        gitRepositoryManager: GitRepositoryManaging,
        modelSelectionStore: ModelSelectionStore,
        modelRepository: ModelListingRepository,
        promptRepository: PromptStreamingRepository,
        onFixLogsRequest: ((String) -> Void)?
    ) {
        self.shellViewModel = shellViewModel
        self.project = project
        self.controlCenterResolver = controlCenterResolver
        self.controlCenterRuntimeManager = controlCenterRuntimeManager
        self.onFixLogsRequest = onFixLogsRequest
        _viewModel = StateObject(
            wrappedValue: ContextPaneViewModel(
                gitRepositoryManager: gitRepositoryManager,
                modelSelectionStore: modelSelectionStore,
                modelRepository: modelRepository,
                promptRepository: promptRepository
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let gitErrorMessage = viewModel.gitErrorMessage,
               !gitErrorMessage.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)

                    Text(gitErrorMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Button("Dismiss") {
                        viewModel.clearGitError()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }

            VSplitView {
                controlCenterPanel
                    .frame(minHeight: 220, idealHeight: 320)

                gitPanel
                    .frame(minHeight: 180, idealHeight: 260)
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshGitStatus(projectPath: project.localPath)
            }
        }
        .onChange(of: project.id) { _, _ in
            Task {
                await viewModel.refreshGitStatus(projectPath: project.localPath)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatResponseDidFinish)) { notification in
            guard let projectPath = notification.userInfo?["projectPath"] as? String,
                  projectPath == project.localPath else {
                return
            }

            Task {
                await viewModel.refreshGitStatus(projectPath: project.localPath)
            }
        }
    }

    private var controlCenterPanel: some View {
        ControlCenterView(
            project: project,
            controlCenterResolver: controlCenterResolver,
            controlCenterRuntimeManager: controlCenterRuntimeManager,
            onFixLogsRequest: onFixLogsRequest
        )
    }

    private var gitPanel: some View {
        ContextPaneGitPanelView(
            viewModel: viewModel,
            onInitializeGit: {
                Task {
                    await viewModel.initializeGitRepository(projectPath: project.localPath)
                }
            },
            onCommit: {
                Task {
                    await viewModel.commit(projectPath: project.localPath)
                }
            }
        )
    }
}

//#Preview {
//    let environment = AppEnvironment.preview()
//    let project = environment.shellViewModel.activeProject ?? ProjectRef(name: "Preview", localPath: "~/CopilotForgeProjects/preview")
//    ContextPaneView(
//        shellViewModel: environment.shellViewModel,
//        project: project,
//        controlCenterResolver: environment.controlCenterResolver,
//        controlCenterRuntimeManager: environment.controlCenterRuntimeManager,
//        gitRepositoryManager: environment.gitRepositoryManager,
//        onFixLogsRequest: nil
//    )
//}
