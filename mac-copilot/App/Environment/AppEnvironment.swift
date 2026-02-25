import Foundation
import Combine

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

    init() {
        let service = GitHubAuthService()
        let repository = GitHubAuthRepository(service: service)
        self.authViewModel = AuthViewModel(repository: repository)

        let dataStack = SwiftDataStack.shared
        let projectRepository = SwiftDataProjectRepository(context: dataStack.context)
        let chatRepository = SwiftDataChatRepository(context: dataStack.context)
        self.chatRepository = chatRepository
        self.shellViewModel = ShellViewModel(projectRepository: projectRepository, chatRepository: chatRepository)

        let copilotAPIService = CopilotAPIService()
        let copilotRepository = CopilotPromptRepository(apiService: copilotAPIService)
        self.promptRepository = copilotRepository
        self.modelRepository = copilotRepository
        self.profileRepository = GitHubProfileRepository()
        self.previewResolver = ProjectPreviewResolver(adapters: [
            SimpleHTMLPreviewAdapter()
        ])
        self.previewRuntimeManager = PreviewRuntimeManager(adapters: [
            NodeRuntimeAdapter(),
            PythonRuntimeAdapter(),
            SimpleHTMLRuntimeAdapter(),
        ])
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
