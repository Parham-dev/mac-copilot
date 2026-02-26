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
    private let modelSelectionStore: ModelSelectionStore
    private let fetchModelCatalogUseCase: FetchModelCatalogUseCase
    private let sendPromptUseCase: SendPromptUseCase
    private var aiGenerationRetryAfter: Date?

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
        self.modelSelectionStore = modelSelectionStore
        self.fetchModelCatalogUseCase = FetchModelCatalogUseCase(repository: modelRepository)
        self.sendPromptUseCase = SendPromptUseCase(repository: promptRepository)
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

        isPerformingGitAction = true
        defer { isPerformingGitAction = false }

        let trimmedMessage = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveMessage: String

        if trimmedMessage.isEmpty {
            if shouldAttemptAIGeneration {
                do {
                    effectiveMessage = try await generateCommitMessageWithAI(projectPath: projectPath)
                    aiGenerationRetryAfter = nil
                } catch {
                    aiGenerationRetryAfter = Date().addingTimeInterval(60)
                    let fallback = generateCommitMessage()
                    effectiveMessage = fallback
                }
            } else {
                effectiveMessage = generateCommitMessage()
            }
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

    private func generateCommitMessageWithAI(projectPath: String) async throws -> String {
        let model = await resolvePreferredModel()
        let prompt = buildCommitMessagePrompt()

        var generatedText = ""

        for try await event in sendPromptUseCase.execute(
            prompt: prompt,
            chatID: UUID(),
            model: model,
            projectPath: projectPath,
            allowedTools: nil
        ) {
            if case .textDelta(let chunk) = event {
                generatedText += chunk
            }
        }

        let normalized = generatedText
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let firstLine = normalized
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if firstLine.isEmpty {
            throw GitRepositoryError(message: "AI did not return a commit message.")
        }

        return firstLine
    }

    private func resolvePreferredModel() async -> String? {
        let models = await fetchModelCatalogUseCase.execute().map(\.id)
        guard !models.isEmpty else { return nil }

        let preferredVisible = Set(modelSelectionStore.selectedModelIDs())
        if preferredVisible.isEmpty {
            return models.first
        }

        let filtered = models.filter { preferredVisible.contains($0) }
        return (filtered.isEmpty ? models : filtered).first
    }

    private func buildCommitMessagePrompt() -> String {
        let summarizedChanges = allGitFileChanges.prefix(20).map { change in
            "- [\(change.state.rawValue)] \(change.path) (+\(change.addedLines)/-\(change.deletedLines))"
        }.joined(separator: "\n")

        return """
        Generate a concise Git commit message for these changes.

        CRITICAL OUTPUT RULES:
        - Respond with ONLY the commit message subject line.
        - Do NOT include any explanation, prefix, suffix, markdown, code fences, or quotes.
        - Do NOT say things like "Here is" or "Let me".
        - Maximum 72 characters.
        - One line only.

        Valid example output:
        Update git panel commit message generation

        Changes:
        \(summarizedChanges)
        """
    }

    private var shouldAttemptAIGeneration: Bool {
        guard let aiGenerationRetryAfter else {
            return true
        }

        return Date() >= aiGenerationRetryAfter
    }

    func clearGitError() {
        gitErrorMessage = nil
    }
}
