import SwiftUI

struct AgentsDetailView: View {
    @EnvironmentObject private var agentsEnvironment: AgentsEnvironment
    let selection: AnyHashable?

    var body: some View {
        if let item = selection as? AgentsFeatureModule.SidebarItem {
            switch item {
            case .agent(let agentID):
                if let definition = agentsEnvironment.definition(id: agentID) {
                    agentPlaceholder(definition: definition)
                } else {
                    ContentUnavailableView("Agent not found", systemImage: "exclamationmark.triangle")
                }
            }
        } else {
            ContentUnavailableView("Select an agent", systemImage: "person.crop.circle.badge.questionmark")
        }
    }

    private func agentPlaceholder(definition: AgentDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(definition.name)
                .font(.title2)
                .fontWeight(.semibold)

            Text(definition.description)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Planned inputs")
                    .font(.headline)
                ForEach(definition.inputSchema.fields, id: \.id) { field in
                    let suffix = field.required ? "(required)" : "(optional)"
                    Text("• \(field.id) \(suffix)")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
