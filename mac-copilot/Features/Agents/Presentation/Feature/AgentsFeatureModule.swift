import SwiftUI

/// Builds the `FeatureModule` descriptor for the Agents feature.
enum AgentsFeatureModule {

    static let featureID = "agents"

    enum SidebarItem: Hashable {
        case agent(String)
    }

    @MainActor
    static func make(environment: AgentsEnvironment) -> FeatureModule {
        FeatureModule(
            id: featureID,
            sidebarTitle: "Agents",
            sidebarSection: { selectionBinding in
                AnyView(
                    AgentsSidebarSection(selection: selectionBinding)
                        .environmentObject(environment)
                )
            },
            detailView: { selection in
                AnyView(
                    AgentsDetailView(selection: selection)
                        .environmentObject(environment)
                )
            },
            navigationTitle: { selection in
                guard let item = selection as? SidebarItem else {
                    return "Agents"
                }

                switch item {
                case .agent(let agentID):
                    return environment.definition(id: agentID)?.name ?? "Agent"
                }
            }
        )
    }
}
