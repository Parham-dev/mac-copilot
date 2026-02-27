import SwiftUI

struct ContextPaneGitPanelView: View {
    @ObservedObject var viewModel: ContextPaneViewModel
    let onInitializeGit: () -> Void
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GitPanelHeaderView(
                totalAddedLines: viewModel.totalAddedLines,
                totalDeletedLines: viewModel.totalDeletedLines
            )

            if viewModel.hasGitRepository {
                if let status = viewModel.gitRepositoryStatus {
                    GitRepositoryContentView(
                        status: status,
                        hasChanges: viewModel.hasChanges,
                        changesByState: { state in viewModel.changes(for: state) },
                        commitMessage: $viewModel.commitMessage,
                        isPerformingGitAction: viewModel.isPerformingGitAction,
                        canCommit: viewModel.canCommit,
                        onCommit: onCommit,
                        recentCommits: viewModel.recentCommits
                    )
                } else {
                    GitLoadingStatusView()
                }

                Spacer()
            } else {
                GitNoRepositoryView(
                    isInitializingGit: viewModel.isInitializingGit,
                    onInitializeGit: onInitializeGit
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.05))
    }
}
