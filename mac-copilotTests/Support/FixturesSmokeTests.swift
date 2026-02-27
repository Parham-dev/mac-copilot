import Foundation
import Testing
@testable import mac_copilot

/// Smoke tests that verify all shared test fixtures build valid domain objects.
/// If a fixture helper breaks, these tests catch it before domain tests run.
struct FixturesSmokeTests {
    @Test(.tags(.smoke)) func chatMessageFixture_buildsExpectedRoles() {
        let userMessage = ChatMessageFixture.user()
        let assistantMessage = ChatMessageFixture.assistant()

        #expect(userMessage.role == .user)
        #expect(assistantMessage.role == .assistant)
        #expect(!(assistantMessage.metadata?.statusChips.isEmpty ?? true))
    }

    @Test(.tags(.smoke)) func modelCatalogFixture_buildsExpectedJSONShapes() throws {
        let wrappedObjects = try CopilotModelCatalogPayloadFixture.wrappedObjectsData()
        let wrappedStrings = try CopilotModelCatalogPayloadFixture.wrappedStringListData()
        let directStrings = try CopilotModelCatalogPayloadFixture.directStringListData()

        let wrappedObjectsJSON = try #require(JSONSerialization.jsonObject(with: wrappedObjects) as? [String: Any])
        let wrappedStringsJSON = try #require(JSONSerialization.jsonObject(with: wrappedStrings) as? [String: Any])
        let directStringsJSON = try #require(JSONSerialization.jsonObject(with: directStrings) as? [String])

        #expect(wrappedObjectsJSON["models"] != nil)
        #expect(wrappedStringsJSON["models"] != nil)
        #expect(directStringsJSON.count == 2)
    }

    @Test(.tags(.smoke)) func sidecarHealthFixture_buildsHealthySnapshot() {
        let snapshot = SidecarHealthSnapshotFixture.healthy()
        #expect(snapshot.service == "copilotforge-sidecar")
        #expect(snapshot.nodeVersion == "v25.5.0")
        #expect(snapshot.processStartedAtMs != nil)
    }
}
