import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let authViewModel: AuthViewModel
    let shellViewModel: ShellViewModel

    private let promptRepository: PromptStreamingRepository
    private let modelRepository: ModelListingRepository
    private let profileRepository: ProfileRepository
    private var chatViewModels: [String: ChatViewModel] = [:]
    private lazy var profileViewModel: ProfileViewModel = {
        let useCase = FetchProfileUseCase(repository: profileRepository)
        return ProfileViewModel(fetchProfileUseCase: useCase)
    }()

    init() {
        let service = GitHubAuthService()
        let repository = GitHubAuthRepository(service: service)
        self.authViewModel = AuthViewModel(repository: repository)

        let projectStore = UserDefaultsProjectStore()
        self.shellViewModel = ShellViewModel(projectStore: projectStore)

        let copilotAPIService = CopilotAPIService()
        let copilotRepository = CopilotPromptRepository(apiService: copilotAPIService)
        self.promptRepository = copilotRepository
        self.modelRepository = copilotRepository
        self.profileRepository = GitHubProfileRepository()
    }

    func chatViewModel(for chatTitle: String, project: ProjectRef) -> ChatViewModel {
        let cacheKey = "\(project.id.uuidString)|\(chatTitle)"

        if let existing = chatViewModels[cacheKey] {
            return existing
        }

        let sendUseCase = SendPromptUseCase(repository: promptRepository)
        let fetchModelsUseCase = FetchModelsUseCase(repository: modelRepository)
        let created = ChatViewModel(
            chatTitle: chatTitle,
            projectPath: project.localPath,
            sendPromptUseCase: sendUseCase,
            fetchModelsUseCase: fetchModelsUseCase
        )
        chatViewModels[cacheKey] = created
        return created
    }

    func sharedProfileViewModel() -> ProfileViewModel {
        profileViewModel
    }

    static func preview() -> AppEnvironment {
        AppEnvironment()
    }
}
