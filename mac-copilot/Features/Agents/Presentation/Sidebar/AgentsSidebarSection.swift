import SwiftUI

struct AgentsSidebarSection: View {
    @EnvironmentObject private var agentsEnvironment: AgentsEnvironment
    @Binding var selection: AnyHashable?

    var body: some View {
        ForEach(agentsEnvironment.definitions, id: \.id) { definition in
            Label(definition.name, systemImage: "link")
                .tag(AnyHashable(AgentsFeatureModule.SidebarItem.agent(definition.id)))
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = AnyHashable(AgentsFeatureModule.SidebarItem.agent(definition.id))
                }
        }
        .onAppear {
            if agentsEnvironment.definitions.isEmpty {
                agentsEnvironment.loadDefinitions()
            }
        }
    }
}
