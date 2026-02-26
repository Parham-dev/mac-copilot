import Foundation
import Combine

@MainActor
final class ContextPaneViewModel: ObservableObject {
    @Published private(set) var hasGitRepository = false
    @Published private(set) var gitRepositoryStatus: GitRepositoryStatus?
    @Published private(set) var gitFileChanges: [GitFileChange] = []
    @Published private(set) var recentCommits: [GitRecentCommit] = []
    @Published var commitMessage = ""
    @Published private(set) var isInitializingGit = false
    @Published private(set) var isPerformingGitAction = false
    @Published private(set) var gitErrorMessage: String?

    private let checkGitRepositoryUseCase: CheckGitRepositoryUseCase
    private let fetchGitRepositoryStatusUseCase: FetchGitRepositoryStatusUseCase
    private let fetchGitFileChangesUseCase: FetchGitFileChangesUseCase
    private let fetchGitRecentCommitsUseCase: FetchGitRecentCommitsUseCase
    private let initializeGitRepositoryUseCase: InitializeGitRepositoryUseCase
    private let commitGitChangesUseCase: CommitGitChangesUseCase

    init(gitRepositoryManager: GitRepositoryManaging) {
        self.checkGitRepositoryUseCase = CheckGitRepositoryUseCase(repositoryManager: gitRepositoryManager)
        self.fetchGitRepositoryStatusUseCase = FetchGitRepositoryStatusUseCase(repositoryManager: gitRepositoryManager)
        self.fetchGitFileChangesUseCase = FetchGitFileChangesUseCase(repositoryManager: gitRepositoryManager)
        self.fetchGitRecentCommitsUseCase = FetchGitRecentCommitsUseCase(repositoryManager: gitRepositoryManager)
        self.initializeGitRepositoryUseCase = InitializeGitRepositoryUseCase(repositoryManager: gitRepositoryManager)
        self.commitGitChangesUseCase = CommitGitChangesUseCase(repositoryManager: gitRepositoryManager)
    }

    var canCommit: Bool {
        !gitFileChanges.isEmpty && !isPerformingGitAction
    }

    var allGitFileChanges: [GitFileChange] {
        gitFileChanges.sorted { lhs, rhs in
            lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
    }

    var hasChanges: Bool {
        !allGitFileChanges.isEmpty
    }

    var totalAddedLines: Int {
        allGitFileChanges.reduce(0) { partial, change in
            partial + change.addedLines
        }
    }

    var totalDeletedLines: Int {
        allGitFileChanges.reduce(0) { partial, change in
            partial + change.deletedLines
        }
    }

    func changes(for state: GitFileChangeState) -> [GitFileChange] {
        allGitFileChanges.filter { $0.state == state }
    }

    func refreshGitStatus(projectPath: String) async {
        let isRepository = await checkGitRepositoryUseCase.execute(path: projectPath)
        hasGitRepository = isRepository

        guard isRepository else {
            gitRepositoryStatus = nil
            gitFileChanges = []
            recentCommits = []
            return
        }

        do {
            gitRepositoryStatus = try await fetchGitRepositoryStatusUseCase.execute(path: projectPath)
            gitFileChanges = try await fetchGitFileChangesUseCase.execute(path: projectPath)
            recentCommits = try await fetchGitRecentCommitsUseCase.execute(path: projectPath)
        } catch {
            gitRepositoryStatus = nil
            gitFileChanges = []
            recentCommits = []
            let message = error.localizedDescription
            gitErrorMessage = message.isEmpty ? "Could not read Git repository status." : message
        }
    }

    func initializeGitRepository(projectPath: String) async {
        guard !isInitializingGit else { return }
        isInitializingGit = true
        defer { isInitializingGit = false }

        do {
            try await initializeGitRepositoryUseCase.execute(path: projectPath)
            await refreshGitStatus(projectPath: projectPath)
        } catch {
            let message = error.localizedDescription
            gitErrorMessage = message.isEmpty ? "Could not initialize Git repository." : message
        }
    }

    func commit(projectPath: String) async {
        guard !isPerformingGitAction else { return }

        guard !gitFileChanges.isEmpty else {
            gitErrorMessage = "No changes to commit."
            return
        }

        let trimmedMessage = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveMessage = trimmedMessage.isEmpty ? generateCommitMessage() : trimmedMessage
        commitMessage = effectiveMessage

        isPerformingGitAction = true
        defer { isPerformingGitAction = false }

        do {
            try await commitGitChangesUseCase.execute(path: projectPath, message: effectiveMessage)
            commitMessage = ""
            await refreshGitStatus(projectPath: projectPath)
        } catch {
            let errorMessage = error.localizedDescription
            gitErrorMessage = errorMessage.isEmpty ? "Could not commit Git changes." : errorMessage
        }
    }

    private func generateCommitMessage() -> String {
        let changedFileCount = gitFileChanges.count
        if changedFileCount == 1, let single = gitFileChanges.first {
            return "Update \(single.path)"
        }

        return "Update \(changedFileCount) files"
    }

    func clearGitError() {
        gitErrorMessage = nil
    }
}
