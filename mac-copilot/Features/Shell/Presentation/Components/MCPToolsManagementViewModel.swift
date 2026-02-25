import Foundation
import Combine

@MainActor
final class MCPToolsManagementViewModel: ObservableObject {
    @Published private(set) var tools: [MCPToolDefinition] = []
    @Published var enabledToolIDs: Set<String> = []
    @Published var focusedToolID: String?

    private let store: MCPToolsStore

    init(store: MCPToolsStore) {
        self.store = store
    }

    var focusedTool: MCPToolDefinition? {
        guard let focusedToolID else { return tools.first }
        return tools.first(where: { $0.id == focusedToolID })
    }

    func loadTools() {
        guard tools.isEmpty else { return }

        tools = MCPToolsCatalog.all
            .sorted { lhs, rhs in
                if lhs.group == rhs.group {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.group.localizedCaseInsensitiveCompare(rhs.group) == .orderedAscending
            }

        let persisted = Set(store.enabledToolIDs())
        enabledToolIDs = persisted.isEmpty ? Set(tools.map(\.id)) : Set(tools.map(\.id).filter { persisted.contains($0) })

        if focusedToolID == nil {
            focusedToolID = tools.first?.id
        }
    }

    func setTool(_ toolID: String, isEnabled: Bool) {
        if isEnabled {
            enabledToolIDs.insert(toolID)
        } else {
            enabledToolIDs.remove(toolID)
        }
    }

    func enableAll() {
        enabledToolIDs = Set(tools.map(\.id))
    }

    func disableAll() {
        enabledToolIDs.removeAll()
    }

    func save() {
        store.setEnabledToolIDs(Array(enabledToolIDs))
    }
}
