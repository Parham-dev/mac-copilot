import Foundation
import FactoryKit

extension Container {
    var sidecarLifecycleManager: Factory<any SidecarLifecycleManaging> {
        self { @MainActor in SidecarManager() }
            .singleton
    }

    var swiftDataStack: Factory<any SwiftDataStoreProviding> {
        self { @MainActor in SwiftDataStack() }
            .singleton
    }

    var modelSelectionPreferencesStore: Factory<ModelSelectionPreferencesStoring> {
        self { @MainActor in UserDefaultsModelSelectionPreferencesStore() }
            .singleton
    }

    var mcpToolsPreferencesStore: Factory<MCPToolsPreferencesStoring> {
        self { @MainActor in UserDefaultsMCPToolsPreferencesStore() }
            .singleton
    }

    var modelSelectionStore: Factory<ModelSelectionStore> {
        self { @MainActor in ModelSelectionStore(preferencesStore: self.modelSelectionPreferencesStore()) }
            .singleton
    }

    var mcpToolsStore: Factory<MCPToolsStore> {
        self { @MainActor in MCPToolsStore(preferencesStore: self.mcpToolsPreferencesStore()) }
            .singleton
    }

    var chatEventsStore: Factory<ChatEventsStore> {
        self { @MainActor in ChatEventsStore() }
            .singleton
    }
}