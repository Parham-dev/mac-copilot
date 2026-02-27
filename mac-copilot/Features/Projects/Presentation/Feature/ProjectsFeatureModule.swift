import SwiftUI

/// Builds the `FeatureModule` descriptor for the Projects feature.
///
/// Call `ProjectsFeatureModule.make(environment:)` once in `AppEnvironment`
/// and register the result in `AppFeatureRegistry`. No shell file needs to
/// import any Projects-specific type.
enum ProjectsFeatureModule {

    static let featureID = "projects"

    /// Creates a fully wired `FeatureModule` for the Projects feature.
    ///
    /// - Parameter environment: The `ProjectsEnvironment` instance that owns
    ///   all Projects dependencies. It is captured by the returned closures and
    ///   injected as an environment object.
    @MainActor
    static func make(environment: ProjectsEnvironment) -> FeatureModule {
        FeatureModule(
            id: featureID,
            sidebarTitle: "Projects",
            sidebarSection: { selectionBinding in
                AnyView(
                    ProjectsSidebarSection(selection: selectionBinding)
                        .environmentObject(environment)
                )
            },
            detailView: { selection in
                AnyView(
                    ProjectsDetailView(selection: selection)
                        .environmentObject(environment)
                )
            },
            navigationTitle: { selection in
                guard let item = selection as? ProjectsViewModel.SidebarItem else {
                    return "Projects"
                }
                switch item {
                case .chat(let projectID, let chatID):
                    let vm = environment.projectsViewModel
                    return vm.chat(for: chatID, in: projectID)?.title ?? "Chat"
                }
            }
        )
    }
}
