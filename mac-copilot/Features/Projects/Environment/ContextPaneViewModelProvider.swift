import Foundation

/// Vends `ContextPaneViewModel` instances, one per project.
///
/// Caches by project ID so that `ContextPaneView` (which uses `@StateObject`)
/// always receives the same instance for the same project — identical to how
/// `ChatViewModelProvider` caches by project+chat ID.
/// Without caching, every call to `viewModel(for:)` would create a fresh
/// instance that `@StateObject` silently discards after first init, leaving the
/// context pane showing stale git/control-centre state when switching projects.
@MainActor
final class ContextPaneViewModelProvider {
    private let gitRepositoryManager: GitRepositoryManaging
    private let modelSelectionStore: ModelSelectionStore
    private let modelRepository: ModelListingRepository
    private let promptRepository: PromptStreamingRepository

    private var cache: [UUID: ContextPaneViewModel] = [:]

    init(
        gitRepositoryManager: GitRepositoryManaging,
        modelSelectionStore: ModelSelectionStore,
        modelRepository: ModelListingRepository,
        promptRepository: PromptStreamingRepository
    ) {
        self.gitRepositoryManager = gitRepositoryManager
        self.modelSelectionStore = modelSelectionStore
        self.modelRepository = modelRepository
        self.promptRepository = promptRepository
    }

    /// Returns the cached view model for `projectID`, creating one on first access.
    func viewModel(for projectID: UUID) -> ContextPaneViewModel {
        if let existing = cache[projectID] { return existing }
        let vm = ContextPaneViewModel(
            gitRepositoryManager: gitRepositoryManager,
            modelSelectionStore: modelSelectionStore,
            modelRepository: modelRepository,
            promptRepository: promptRepository
        )
        cache[projectID] = vm
        return vm
    }

    /// Removes the cached view model for a deleted/invalidated project.
    func evict(projectID: UUID) {
        cache.removeValue(forKey: projectID)
    }

    /// Clears all cached view models.
    func evictAll() {
        cache.removeAll()
    }
}