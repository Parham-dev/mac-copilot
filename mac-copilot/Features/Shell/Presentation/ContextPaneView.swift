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
        onFixLogsRequest: ((String) -> Void)?
    ) {
        self.shellViewModel = shellViewModel
        self.project = project
        self.controlCenterResolver = controlCenterResolver
        self.controlCenterRuntimeManager = controlCenterRuntimeManager
        self.onFixLogsRequest = onFixLogsRequest
        _viewModel = StateObject(wrappedValue: ContextPaneViewModel(gitRepositoryManager: gitRepositoryManager))
    }

    var body: some View {
        VSplitView {
            controlCenterPanel
                .frame(minHeight: 220, idealHeight: 320)

            gitPanel
                .frame(minHeight: 180, idealHeight: 260)
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
        .alert("Git", isPresented: gitErrorAlertBinding) {
            Button("OK", role: .cancel) {
                viewModel.clearGitError()
            }
        } message: {
            Text(viewModel.gitErrorMessage ?? "Unknown error")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                panelTitle("Git", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                Spacer()
                HStack(spacing: 4) {
                    Text("+\(viewModel.totalAddedLines)")
                        .foregroundStyle(.green)
                    Text("/")
                        .foregroundStyle(.secondary)
                    Text("-\(viewModel.totalDeletedLines)")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }

            if viewModel.hasGitRepository {
                VStack(alignment: .leading, spacing: 6) {
                    if let status = viewModel.gitRepositoryStatus {
                        Text("Branch: \(status.branchName)")
                            .font(.body)
                        Text(status.statusText)
                            .font(.body)
                            .foregroundStyle(status.isClean ? .secondary : .primary)

                        if viewModel.hasChanges {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(GitFileChangeState.allCases, id: \.self) { state in
                                        let sectionChanges = viewModel.changes(for: state)
                                        if !sectionChanges.isEmpty {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(state.title)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)

                                                ForEach(sectionChanges) { change in
                                                    GitChangeRowView(change: change)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        } else {
                            Text("No changes")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $viewModel.commitMessage)
                                    .font(.body)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(minHeight: 19)

                                if viewModel.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("If left empty, message will be generated by AI")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 14)
                                        .padding(.leading, 14)
                                        .allowsHitTesting(false)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                            )

                            HStack {
                                Spacer()
                                Button {
                                    Task {
                                        await viewModel.commit(projectPath: project.localPath)
                                    }
                                } label: {
                                    if viewModel.isPerformingGitAction {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text("Commit")
                                    }
                                }
                                .disabled(!viewModel.canCommit)
                            }

                            if !viewModel.recentCommits.isEmpty {
                                Divider()
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Recent Commits")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    ForEach(viewModel.recentCommits) { commit in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(commit.message)
                                                .font(.caption)
                                                .lineLimit(1)

                                            Text("\(commit.shortHash) • \(commit.author) • \(commit.relativeTime)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading Git status…")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Text("No Git repository found")
                        .font(.body)

                    Button {
                        Task {
                            await viewModel.initializeGitRepository(projectPath: project.localPath)
                        }
                    } label: {
                        if viewModel.isInitializingGit {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Init Git", systemImage: "plus.square.on.square")
                        }
                    }
                    .disabled(viewModel.isInitializingGit)
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
            get: { viewModel.gitErrorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.clearGitError()
                }
            }
        )
    }
}

private struct GitChangeRowView: View {
    let change: GitFileChange

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(change.state.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)

            Text(change.path)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text("+\(change.addedLines)")
                    .foregroundStyle(.green)
                Text("/")
                    .foregroundStyle(.secondary)
                Text("-\(change.deletedLines)")
                    .foregroundStyle(.red)
            }
            .font(.caption)
        }
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
