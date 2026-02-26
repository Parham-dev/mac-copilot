import Foundation

@MainActor
final class ContextPaneViewModelProvider {
    private let gitRepositoryManager: GitRepositoryManaging
    private let modelSelectionStore: ModelSelectionStore
    private let modelRepository: ModelListingRepository
    private let promptRepository: PromptStreamingRepository

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

    func makeViewModel() -> ContextPaneViewModel {
        ContextPaneViewModel(
            gitRepositoryManager: gitRepositoryManager,
            modelSelectionStore: modelSelectionStore,
            modelRepository: modelRepository,
            promptRepository: promptRepository
        )
    }
}