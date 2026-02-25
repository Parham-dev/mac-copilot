import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let authViewModel: AuthViewModel
    let shellViewModel: ShellViewModel

    private let promptRepository: PromptStreamingRepository
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
        self.promptRepository = CopilotPromptRepository(apiService: copilotAPIService)
        self.profileRepository = GitHubProfileRepository()
    }

    func chatViewModel(for chatTitle: String, project: ProjectRef) -> ChatViewModel {
        let cacheKey = "\(project.id.uuidString)|\(chatTitle)"

        if let existing = chatViewModels[cacheKey] {
            return existing
        }

        let useCase = SendPromptUseCase(repository: promptRepository)
        let created = ChatViewModel(chatTitle: chatTitle, sendPromptUseCase: useCase)
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
