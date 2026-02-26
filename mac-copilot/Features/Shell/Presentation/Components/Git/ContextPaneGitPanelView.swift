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

private struct GitPanelHeaderView: View {
    let totalAddedLines: Int
    let totalDeletedLines: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.title3)
                Text("Git")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("+\(totalAddedLines)")
                    .foregroundStyle(.green)
                Text("/")
                    .foregroundStyle(.secondary)
                Text("-\(totalDeletedLines)")
                    .foregroundStyle(.red)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
        }
    }
}

private struct GitRepositoryContentView: View {
    let status: GitRepositoryStatus
    let hasChanges: Bool
    let changesByState: (GitFileChangeState) -> [GitFileChange]
    @Binding var commitMessage: String
    let isPerformingGitAction: Bool
    let canCommit: Bool
    let onCommit: () -> Void
    let recentCommits: [GitRecentCommit]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Branch: \(status.branchName)")
                .font(.body)
            Text(status.statusText)
                .font(.body)
                .foregroundStyle(status.isClean ? .secondary : .primary)

            if hasChanges {
                GitChangesListView(changesByState: changesByState)
            } else {
                Text("No changes")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            GitCommitComposerSectionView(
                commitMessage: $commitMessage,
                isPerformingGitAction: isPerformingGitAction,
                canCommit: canCommit,
                onCommit: onCommit,
                recentCommits: recentCommits
            )
        }
    }
}

private struct GitChangesListView: View {
    let changesByState: (GitFileChangeState) -> [GitFileChange]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(GitFileChangeState.allCases, id: \.self) { state in
                    let sectionChanges = changesByState(state)
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
    }
}

private struct GitCommitComposerSectionView: View {
    @Binding var commitMessage: String
    let isPerformingGitAction: Bool
    let canCommit: Bool
    let onCommit: () -> Void
    let recentCommits: [GitRecentCommit]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $commitMessage)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 19)

                if commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("If left empty, commit message will be generated by AI")
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
                Button(action: onCommit) {
                    if isPerformingGitAction {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Commit")
                    }
                }
                .disabled(!canCommit)
            }

            if !recentCommits.isEmpty {
                GitRecentCommitsSectionView(recentCommits: recentCommits)
            }
        }
    }
}

private struct GitRecentCommitsSectionView: View {
    let recentCommits: [GitRecentCommit]

    private var maxVisibleRows: Int { 3 }
    private var rowHeight: CGFloat { 34 }

    private var visibleRowCount: Int {
        min(recentCommits.count, maxVisibleRows)
    }

    private var listHeight: CGFloat {
        CGFloat(visibleRowCount) * rowHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.top, 2)

            Text("Recent Commits")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: recentCommits.count > maxVisibleRows) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recentCommits) { commit in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(commit.message)
                                .font(.caption)
                                .lineLimit(1)

                            Text("\(commit.shortHash) • \(commit.author) • \(commit.relativeTime)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.trailing, recentCommits.count > maxVisibleRows ? 4 : 0)
            }
            .frame(height: listHeight)
        }
    }
}

private struct GitLoadingStatusView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading Git status…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GitNoRepositoryView: View {
    let isInitializingGit: Bool
    let onInitializeGit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            Text("No Git repository found")
                .font(.body)

            Button(action: onInitializeGit) {
                if isInitializingGit {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Init Git", systemImage: "plus.square.on.square")
                }
            }
            .disabled(isInitializingGit)

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
