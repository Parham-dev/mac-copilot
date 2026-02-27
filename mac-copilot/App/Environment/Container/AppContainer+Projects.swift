import Foundation
import FactoryKit

extension Container {

    var shellViewModel: Factory<ShellViewModel> {
        self { @MainActor in
            ShellViewModel(defaultFeatureID: ProjectsFeatureModule.featureID)
        }
        .singleton
    }

    var projectsViewModel: Factory<ProjectsViewModel> {
        self { @MainActor in
            ProjectsViewModel(
                projectRepository: self.projectRepository(),
                chatRepository: self.chatRepository()
            )
        }
        .singleton
    }

    var contextPaneViewModelProvider: Factory<ContextPaneViewModelProvider> {
        self { @MainActor in
            ContextPaneViewModelProvider(
                gitRepositoryManager: self.gitRepositoryManager(),
                modelSelectionStore: self.modelSelectionStore(),
                modelRepository: self.modelRepository(),
                promptRepository: self.promptRepository()
            )
        }
        .singleton
    }

    var projectsEnvironment: Factory<ProjectsEnvironment> {
        self { @MainActor in
            ProjectsEnvironment(
                projectsViewModel: self.projectsViewModel(),
                projectCreationService: self.projectCreationService(),
                appUpdateManager: self.appUpdateManager(),
                chatViewModelProvider: self.chatViewModelProvider(),
                contextPaneViewModelProvider: self.contextPaneViewModelProvider(),
                controlCenterResolver: self.controlCenterResolver(),
                controlCenterRuntimeManager: self.controlCenterRuntimeManager(),
                gitRepositoryManager: self.gitRepositoryManager(),
                modelSelectionStore: self.modelSelectionStore(),
                nativeToolsStore: self.nativeToolsStore(),
                chatEventsStore: self.chatEventsStore(),
                modelRepository: self.modelRepository(),
                promptRepository: self.promptRepository()
            )
        }
        .singleton
    }

    var projectsShellBridge: Factory<ProjectsShellBridge> {
        self { @MainActor in
            ProjectsShellBridge(
                projectsViewModel: self.projectsViewModel(),
                appUpdateManager: self.appUpdateManager(),
                chatEventsStore: self.chatEventsStore()
            )
        }
        .singleton
    }

    var profileEnvironment: Factory<ProfileEnvironment> {
        self { @MainActor in
            ProfileEnvironment(profileViewModel: self.profileViewModel())
        }
        .singleton
    }
}
