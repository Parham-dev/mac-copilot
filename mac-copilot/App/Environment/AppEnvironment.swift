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

        let chatListStore = InMemoryChatListStore()
        self.shellViewModel = ShellViewModel(chatListStore: chatListStore)

        let copilotAPIService = CopilotAPIService()
        self.promptRepository = CopilotPromptRepository(apiService: copilotAPIService)
        self.profileRepository = GitHubProfileRepository()
    }

    func chatViewModel(for chatTitle: String) -> ChatViewModel {
        if let existing = chatViewModels[chatTitle] {
            return existing
        }

        let useCase = SendPromptUseCase(repository: promptRepository)
        let created = ChatViewModel(chatTitle: chatTitle, sendPromptUseCase: useCase)
        chatViewModels[chatTitle] = created
        return created
    }

    func sharedProfileViewModel() -> ProfileViewModel {
        profileViewModel
    }

    static func preview() -> AppEnvironment {
        AppEnvironment()
    }
}
