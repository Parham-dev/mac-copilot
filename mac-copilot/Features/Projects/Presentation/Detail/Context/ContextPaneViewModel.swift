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
    private let commitMessageAssistant: CommitMessageAssistantService

    init(
        gitRepositoryManager: GitRepositoryManaging,
        modelSelectionStore: ModelSelectionStore,
        modelRepository: ModelListingRepository,
        promptRepository: PromptStreamingRepository
    ) {
        self.checkGitRepositoryUseCase = CheckGitRepositoryUseCase(repositoryManager: gitRepositoryManager)
        self.fetchGitRepositoryStatusUseCase = FetchGitRepositoryStatusUseCase(repositoryManager: gitRepositoryManager)
        self.fetchGitFileChangesUseCase = FetchGitFileChangesUseCase(repositoryManager: gitRepositoryManager)
        self.fetchGitRecentCommitsUseCase = FetchGitRecentCommitsUseCase(repositoryManager: gitRepositoryManager)
        self.initializeGitRepositoryUseCase = InitializeGitRepositoryUseCase(repositoryManager: gitRepositoryManager)
        self.commitGitChangesUseCase = CommitGitChangesUseCase(repositoryManager: gitRepositoryManager)
        self.commitMessageAssistant = CommitMessageAssistantService(
            modelSelectionStore: modelSelectionStore,
            modelRepository: modelRepository,
            promptRepository: promptRepository
        )
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
            gitErrorMessage = UserFacingErrorMapper.message(error, fallback: "Could not read Git repository status.")
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
            gitErrorMessage = UserFacingErrorMapper.message(error, fallback: "Could not initialize Git repository.")
        }
    }

    func commit(projectPath: String) async {
        guard !isPerformingGitAction else { return }

        guard !gitFileChanges.isEmpty else {
            gitErrorMessage = "No changes to commit."
            return
        }

        isPerformingGitAction = true
        defer { isPerformingGitAction = false }

        let trimmedMessage = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveMessage: String

        if trimmedMessage.isEmpty {
            let aiSuggested = await commitMessageAssistant.generateMessageIfAvailable(
                changes: allGitFileChanges,
                projectPath: projectPath
            )
            effectiveMessage = aiSuggested ?? generateCommitMessage()
        } else {
            effectiveMessage = trimmedMessage
        }

        do {
            try await commitGitChangesUseCase.execute(path: projectPath, message: effectiveMessage)
            commitMessage = ""
            await refreshGitStatus(projectPath: projectPath)
        } catch {
            if trimmedMessage.isEmpty {
                commitMessage = effectiveMessage
            }
            gitErrorMessage = UserFacingErrorMapper.message(error, fallback: "Could not commit Git changes.")
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
