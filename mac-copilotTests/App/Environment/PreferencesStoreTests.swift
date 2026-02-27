import Foundation
import Testing
@testable import mac_copilot

/// Round-trip integration tests for the UserDefaults-backed preferences stores.
///
/// Each test gets a fresh, isolated UserDefaults suite so it never touches
/// `.standard` and cannot be affected by other tests or leaked state.
@MainActor
struct PreferencesStoreTests {

    // MARK: - ModelSelection — write then read

    @Test(.tags(.integration)) func modelSelection_writtenIDsAreReadBackUnchanged() {
        let (store, _) = makeModelSelectionStore()
        let ids = ["claude-3-5-sonnet", "gpt-4o", "gemini-1.5-pro"]

        store.writeSelectedModelIDs(ids)

        #expect(store.readSelectedModelIDs() == ids)
    }

    @Test(.tags(.integration)) func modelSelection_emptyWriteClearsStoredIDs() {
        let (store, _) = makeModelSelectionStore()
        store.writeSelectedModelIDs(["gpt-5"])

        store.writeSelectedModelIDs([])

        #expect(store.readSelectedModelIDs().isEmpty)
    }

    @Test(.tags(.integration)) func modelSelection_defaultsToEmptyWhenNothingStored() {
        let (store, _) = makeModelSelectionStore()

        #expect(store.readSelectedModelIDs().isEmpty)
    }

    @Test(.tags(.integration)) func modelSelection_overwriteReplacesExistingValue() {
        let (store, _) = makeModelSelectionStore()
        store.writeSelectedModelIDs(["old-model"])

        store.writeSelectedModelIDs(["new-model-a", "new-model-b"])

        #expect(store.readSelectedModelIDs() == ["new-model-a", "new-model-b"])
    }

    @Test(.tags(.integration)) func modelSelection_twoStoresWithSameKeyShareState() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let key = "shared.selectedModelIDs"

        let storeA = UserDefaultsModelSelectionPreferencesStore(key: key, defaults: defaults)
        let storeB = UserDefaultsModelSelectionPreferencesStore(key: key, defaults: defaults)

        storeA.writeSelectedModelIDs(["shared-model"])

        #expect(storeB.readSelectedModelIDs() == ["shared-model"])
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test(.tags(.integration)) func modelSelection_twoStoresWithDifferentKeysDontInterfere() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let storeA = UserDefaultsModelSelectionPreferencesStore(key: "keyA", defaults: defaults)
        let storeB = UserDefaultsModelSelectionPreferencesStore(key: "keyB", defaults: defaults)

        storeA.writeSelectedModelIDs(["model-a"])
        storeB.writeSelectedModelIDs(["model-b"])

        #expect(storeA.readSelectedModelIDs() == ["model-a"])
        #expect(storeB.readSelectedModelIDs() == ["model-b"])
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - MCPTools — write then read

    @Test(.tags(.integration)) func mcpTools_writtenIDsAreReadBackUnchanged() {
        let (store, _) = makeMCPToolsStore()
        let ids = ["read_file", "list_dir", "run_command"]

        store.writeEnabledMCPToolIDs(ids)

        #expect(store.readEnabledMCPToolIDs() == ids)
    }

    @Test(.tags(.integration)) func mcpTools_emptyWriteClearsStoredIDs() {
        let (store, _) = makeMCPToolsStore()
        store.writeEnabledMCPToolIDs(["read_file"])

        store.writeEnabledMCPToolIDs([])

        #expect(store.readEnabledMCPToolIDs().isEmpty)
    }

    @Test(.tags(.integration)) func mcpTools_defaultsToEmptyWhenNothingStored() {
        let (store, _) = makeMCPToolsStore()

        #expect(store.readEnabledMCPToolIDs().isEmpty)
    }

    @Test(.tags(.integration)) func mcpTools_overwriteReplacesExistingValue() {
        let (store, _) = makeMCPToolsStore()
        store.writeEnabledMCPToolIDs(["old_tool"])

        store.writeEnabledMCPToolIDs(["new_tool_1", "new_tool_2"])

        #expect(store.readEnabledMCPToolIDs() == ["new_tool_1", "new_tool_2"])
    }

    @Test(.tags(.integration)) func mcpTools_preservesOrderAsWritten() {
        let (store, _) = makeMCPToolsStore()
        let ids = ["zzz_tool", "aaa_tool", "mmm_tool"]

        store.writeEnabledMCPToolIDs(ids)

        // UserDefaults preserves array order; the store must not sort or deduplicate.
        #expect(store.readEnabledMCPToolIDs() == ids)
    }

    // MARK: - ModelSelectionStore + UserDefaults end-to-end

    @Test(.tags(.integration)) func modelSelectionStore_roundTripThroughUserDefaults() {
        let (prefsStore, defaults) = makeModelSelectionStore()
        let store = ModelSelectionStore(preferencesStore: prefsStore)

        store.setSelectedModelIDs(["claude", "gpt-5", "gemini"])

        // Verify the normalised values landed in UserDefaults.
        let stored = defaults.stringArray(forKey: "test.selectedModelIDs") ?? []
        #expect(Set(stored) == Set(["claude", "gpt-5", "gemini"]))
    }

    @Test(.tags(.integration)) func mcpToolsStore_roundTripThroughUserDefaults() {
        let (prefsStore, defaults) = makeMCPToolsStore()
        let store = MCPToolsStore(preferencesStore: prefsStore)

        store.setEnabledToolIDs(["read_file", "list_dir"])

        let stored = defaults.stringArray(forKey: "test.enabledMCPToolIDs") ?? []
        #expect(Set(stored) == Set(["list_dir", "read_file"]))
    }

    // MARK: - ModelSelectionStore changeToken behaviour

    @Test(.tags(.unit)) func modelSelectionStore_changeTokenStartsAtZero() {
        let store = ModelSelectionStore(preferencesStore: InMemoryModelSelectionPreferencesStore([]))
        #expect(store.changeToken == 0)
    }

    @Test(.tags(.unit)) func modelSelectionStore_changeTokenIncrementsOncePerSet() {
        let store = ModelSelectionStore(preferencesStore: InMemoryModelSelectionPreferencesStore([]))

        store.setSelectedModelIDs(["a"])
        #expect(store.changeToken == 1)

        store.setSelectedModelIDs(["b"])
        #expect(store.changeToken == 2)
    }

    @Test(.tags(.unit)) func modelSelectionStore_changeTokenIncrementsByExactlyOne() {
        let store = ModelSelectionStore(preferencesStore: InMemoryModelSelectionPreferencesStore([]))
        let before = store.changeToken

        store.setSelectedModelIDs(["x"])

        #expect(store.changeToken == before + 1)
    }

    @Test(.tags(.unit)) func modelSelectionStore_selectedModelIDsNormalisesOnRead() {
        // Raw stored values are returned verbatim by the in-memory store;
        // selectedModelIDs() must apply NormalizedIDList normalization on top.
        let prefs = InMemoryModelSelectionPreferencesStore(["  gpt-5 ", "", "  ", "claude"])
        let store = ModelSelectionStore(preferencesStore: prefs)

        let result = store.selectedModelIDs()

        #expect(!result.contains(""))
        #expect(!result.contains("  "))
        #expect(result.contains("gpt-5"))
        #expect(result.contains("claude"))
    }

    // MARK: - MCPToolsStore changeToken behaviour

    @Test(.tags(.unit)) func mcpToolsStore_changeTokenStartsAtZero() {
        let store = MCPToolsStore(preferencesStore: InMemoryMCPToolsPreferencesStore([]))
        #expect(store.changeToken == 0)
    }

    @Test(.tags(.unit)) func mcpToolsStore_changeTokenIncrementsOncePerSet() {
        let store = MCPToolsStore(preferencesStore: InMemoryMCPToolsPreferencesStore([]))

        store.setEnabledToolIDs(["read_file"])
        #expect(store.changeToken == 1)

        store.setEnabledToolIDs(["list_dir"])
        #expect(store.changeToken == 2)
    }

    @Test(.tags(.unit)) func mcpToolsStore_enabledToolIDsNormalisesOnRead() {
        let prefs = InMemoryMCPToolsPreferencesStore(["  read_file ", "", "list_dir"])
        let store = MCPToolsStore(preferencesStore: prefs)

        let result = store.enabledToolIDs()

        #expect(!result.contains(""))
        #expect(result.contains("read_file"))
        #expect(result.contains("list_dir"))
    }
}

// MARK: - Private factory helpers

private func makeModelSelectionStore() -> (UserDefaultsModelSelectionPreferencesStore, UserDefaults) {
    let suiteName = "test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let store = UserDefaultsModelSelectionPreferencesStore(
        key: "test.selectedModelIDs",
        defaults: defaults
    )
    return (store, defaults)
}

private func makeMCPToolsStore() -> (UserDefaultsMCPToolsPreferencesStore, UserDefaults) {
    let suiteName = "test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let store = UserDefaultsMCPToolsPreferencesStore(
        key: "test.enabledMCPToolIDs",
        defaults: defaults
    )
    return (store, defaults)
}
