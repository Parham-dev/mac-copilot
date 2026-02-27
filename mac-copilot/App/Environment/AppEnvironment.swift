import Foundation
import Combine
import FactoryKit

@MainActor
final class AppEnvironment: ObservableObject {
    enum LaunchPhase {
        case checking
        case ready
        case failed(String)
    }

    @Published private(set) var launchPhase: LaunchPhase = .checking

    let authEnvironment: AuthEnvironment
    let shellViewModel: ShellViewModel
    let projectsEnvironment: ProjectsEnvironment
    let profileEnvironment: ProfileEnvironment
    let companionEnvironment: CompanionEnvironment
    let featureRegistry: AppFeatureRegistry

    private let bootstrapService: AppBootstrapService
    private let swiftDataStore: any SwiftDataStoreProviding

    init(container: Container = .shared) {
        let swiftDataStore = container.swiftDataStack()
        let authViewModel = container.authViewModel()
        let shellViewModel = container.shellViewModel()
        let companionStatusStore = container.companionStatusStore()
        let projectsEnv = container.projectsEnvironment()
        let profileEnv = container.profileEnvironment()

        self.authEnvironment = AuthEnvironment(authViewModel: authViewModel)
        self.shellViewModel = shellViewModel
        self.projectsEnvironment = projectsEnv
        self.profileEnvironment = profileEnv
        self.companionEnvironment = CompanionEnvironment(companionStatusStore: companionStatusStore)
        self.featureRegistry = AppFeatureRegistry(features: [
            ProjectsFeatureModule.make(environment: projectsEnv),
        ])
        self.bootstrapService = container.appBootstrapService()
        self.swiftDataStore = swiftDataStore
    }

    func bootstrapIfNeeded() async {
        launchPhase = .checking

        if let startupError = swiftDataStore.startupError {
            launchPhase = .failed(startupError)
            return
        }

        await bootstrapService.bootstrapIfNeeded()
        launchPhase = .ready
    }

    static func preview() -> AppEnvironment {
        Container.shared.appEnvironment()
    }
}
