import Foundation
import FactoryKit

extension Container {
    var gitRepositoryManager: Factory<any GitRepositoryManaging> {
        self { @MainActor in LocalGitRepositoryManager() }
            .singleton
    }

    var controlCenterResolver: Factory<ProjectControlCenterResolver> {
        self { @MainActor in
            ProjectControlCenterResolver(adapters: [
                NodeControlCenterAdapter(),
                PythonProjectControlCenterAdapter(),
                SimpleHTMLControlCenterAdapter(),
            ])
        }
        .singleton
    }

    var controlCenterRuntimeManager: Factory<ControlCenterRuntimeManager> {
        self { @MainActor in
            ControlCenterRuntimeManager(adapters: [
                NodeRuntimeAdapter(),
                PythonRuntimeAdapter(),
                SimpleHTMLRuntimeAdapter(),
            ])
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

    var projectCreationService: Factory<ProjectCreationService> {
        self { @MainActor in ProjectCreationService() }
            .singleton
    }
}