import Foundation
import FactoryKit

extension Container {
    var appUpdateManager: Factory<any AppUpdateManaging> {
        self { @MainActor in SparkleAppUpdateManager() }
            .singleton
    }

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

    var nativeToolsPreferencesStore: Factory<NativeToolsPreferencesStoring> {
        self { @MainActor in UserDefaultsNativeToolsPreferencesStore() }
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

    var nativeToolsStore: Factory<NativeToolsStore> {
        self { @MainActor in NativeToolsStore(preferencesStore: self.nativeToolsPreferencesStore()) }
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
