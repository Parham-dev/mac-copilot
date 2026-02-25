import Foundation
import Combine
import FactoryKit

@MainActor
final class AppEnvironment: ObservableObject {
    enum LaunchPhase {
        case checking
        case ready
    }

    @Published private(set) var launchPhase: LaunchPhase = .checking

    let authEnvironment: AuthEnvironment
    let shellEnvironment: ShellEnvironment
    let companionEnvironment: CompanionEnvironment

    private let bootstrapService: AppBootstrapService

    init(container: Container = .shared) {
        let authViewModel = container.authViewModel()
        let chatRepository = container.chatRepository()
        let shellViewModel = ShellViewModel(
            projectRepository: container.projectRepository(),
            chatRepository: chatRepository
        )
        let modelRepository = container.modelRepository()
        let controlCenterResolver = container.controlCenterResolver()
        let controlCenterRuntimeManager = container.controlCenterRuntimeManager()
        let gitRepositoryManager = container.gitRepositoryManager()
        let modelSelectionStore = container.modelSelectionStore()
        let mcpToolsStore = container.mcpToolsStore()
        let companionStatusStore = container.companionStatusStore()
        let profileViewModel = container.profileViewModel()
        let projectCreationService = container.projectCreationService()
        let chatViewModelProvider = container.chatViewModelProvider()

        self.authEnvironment = AuthEnvironment(authViewModel: authViewModel)
        self.shellEnvironment = ShellEnvironment(
            shellViewModel: shellViewModel,
            modelRepository: modelRepository,
            controlCenterResolver: controlCenterResolver,
            controlCenterRuntimeManager: controlCenterRuntimeManager,
            gitRepositoryManager: gitRepositoryManager,
            modelSelectionStore: modelSelectionStore,
            mcpToolsStore: mcpToolsStore,
            profileViewModel: profileViewModel,
            projectCreationService: projectCreationService,
            chatViewModelProvider: chatViewModelProvider
        )
        self.companionEnvironment = CompanionEnvironment(companionStatusStore: companionStatusStore)
        self.bootstrapService = container.appBootstrapService()
    }

    func bootstrapIfNeeded() async {
        launchPhase = .checking
        await bootstrapService.bootstrapIfNeeded()
        launchPhase = .ready
    }

    static func preview() -> AppEnvironment {
        Container.shared.appEnvironment()
    }
}
