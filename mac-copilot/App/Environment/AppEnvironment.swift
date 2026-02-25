import Foundation
import Combine
import FactoryKit

@MainActor
final class AppEnvironment: ObservableObject {
    let authViewModel: AuthViewModel
    let shellViewModel: ShellViewModel

    private let promptRepository: PromptStreamingRepository
    private let modelRepository: ModelListingRepository
    private let profileRepository: ProfileRepository
    private let chatRepository: ChatRepository
    private let previewResolver: ProjectPreviewResolver
    private let previewRuntimeManager: PreviewRuntimeManager
    private var chatViewModels: [String: ChatViewModel] = [:]
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
    }

    func chatViewModel(for chat: ChatThreadRef, project: ProjectRef) -> ChatViewModel {
        let cacheKey = "\(project.id.uuidString)|\(chat.id.uuidString)"

        if let existing = chatViewModels[cacheKey] {
            return existing
        }

        let sendUseCase = SendPromptUseCase(repository: promptRepository)
        let fetchModelsUseCase = FetchModelsUseCase(repository: modelRepository)
        let created = ChatViewModel(
            chatID: chat.id,
            chatTitle: chat.title,
            projectPath: project.localPath,
            sendPromptUseCase: sendUseCase,
            fetchModelsUseCase: fetchModelsUseCase,
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

    static func preview() -> AppEnvironment {
        AppEnvironment()
    }
}
