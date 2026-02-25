import Foundation
import Combine
import FactoryKit

@MainActor
final class ModelSelectionStore: ObservableObject {
    private static let selectedModelIDsKey = "copilotforge.selectedModelIDs"
    @Published private(set) var changeToken: Int = 0

    func selectedModelIDs() -> [String] {
        let raw = UserDefaults.standard.stringArray(forKey: ModelSelectionStore.selectedModelIDsKey) ?? []
        return Self.normalize(raw)
    }

    func setSelectedModelIDs(_ ids: [String]) {
        let normalized = Self.normalize(ids)
        UserDefaults.standard.set(normalized, forKey: ModelSelectionStore.selectedModelIDsKey)
        changeToken += 1
    }

    private static func normalize(_ ids: [String]) -> [String] {
        let trimmed = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(trimmed)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

@MainActor
final class AppEnvironment: ObservableObject {
    enum LaunchPhase {
        case checking
        case ready
    }

    let authViewModel: AuthViewModel
    let shellViewModel: ShellViewModel
    @Published private(set) var launchPhase: LaunchPhase = .checking

    private let promptRepository: PromptStreamingRepository
    private let modelRepository: ModelListingRepository
    private let profileRepository: ProfileRepository
    private let chatRepository: ChatRepository
    private let previewResolver: ProjectPreviewResolver
    private let previewRuntimeManager: PreviewRuntimeManager
    let modelSelectionStore: ModelSelectionStore
    private var chatViewModels: [String: ChatViewModel] = [:]
    private var didBootstrap = false
    private lazy var profileViewModel: ProfileViewModel = {
        let useCase = FetchProfileUseCase(repository: profileRepository)
        return ProfileViewModel(fetchProfileUseCase: useCase)
    }()

    init(container: Container = .shared) {
        self.authViewModel = container.authViewModel()
        self.chatRepository = container.chatRepository()
        self.shellViewModel = ShellViewModel(
            projectRepository: container.projectRepository(),
            chatRepository: self.chatRepository
        )
        self.promptRepository = container.promptRepository()
        self.modelRepository = container.modelRepository()
        self.profileRepository = container.profileRepository()
        self.previewResolver = container.previewResolver()
        self.previewRuntimeManager = container.previewRuntimeManager()
        self.modelSelectionStore = ModelSelectionStore()
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        launchPhase = .checking
        SidecarManager.shared.startIfNeeded()
        await authViewModel.restoreSessionIfNeeded()
        launchPhase = .ready
    }

    func chatViewModel(for chat: ChatThreadRef, project: ProjectRef) -> ChatViewModel {
        let cacheKey = "\(project.id.uuidString)|\(chat.id.uuidString)"

        if let existing = chatViewModels[cacheKey] {
            return existing
        }

        let sendUseCase = SendPromptUseCase(repository: promptRepository)
        let fetchModelsUseCase = FetchModelsUseCase(repository: modelRepository)
        let fetchModelCatalogUseCase = FetchModelCatalogUseCase(repository: modelRepository)
        let created = ChatViewModel(
            chatID: chat.id,
            chatTitle: chat.title,
            projectPath: project.localPath,
            sendPromptUseCase: sendUseCase,
            fetchModelsUseCase: fetchModelsUseCase,
            fetchModelCatalogUseCase: fetchModelCatalogUseCase,
            modelSelectionStore: modelSelectionStore,
            chatRepository: chatRepository
        )
        chatViewModels[cacheKey] = created
        return created
    }

    func sharedProfileViewModel() -> ProfileViewModel {
        profileViewModel
    }

    func sharedPreviewResolver() -> ProjectPreviewResolver {
        previewResolver
    }

    func sharedPreviewRuntimeManager() -> PreviewRuntimeManager {
        previewRuntimeManager
    }

    func sharedModelSelectionStore() -> ModelSelectionStore {
        modelSelectionStore
    }

    static func preview() -> AppEnvironment {
        AppEnvironment()
    }
}
