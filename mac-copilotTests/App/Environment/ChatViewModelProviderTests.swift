import Foundation
import Testing
@testable import mac_copilot

/// Tests for ChatViewModelProvider's caching contract.
///
/// The provider must return the *same* ChatViewModel instance when called
/// with identical (project, chat) pairs, and a *different* instance when
/// either the project ID or the chat ID differs.
@MainActor
struct ChatViewModelProviderTests {

    // MARK: - Helpers

    private func makeProvider() -> ChatViewModelProvider {
        ChatViewModelProvider(
            promptRepository: FakePromptStreamingRepository(),
            modelRepository: FakeModelListingRepository(models: [], catalog: []),
            chatRepository: InMemoryChatRepository(),
            modelSelectionStore: ModelSelectionStore(
                preferencesStore: InMemoryModelSelectionPreferencesStore([])
            ),
            nativeToolsStore: NativeToolsStore(
                preferencesStore: InMemoryNativeToolsPreferencesStore([])
            ),
            chatEventsStore: ChatEventsStore()
        )
    }

    private func makeProject(id: UUID = UUID()) -> ProjectRef {
        ProjectRef(id: id, name: "Test Project", localPath: "/tmp/project")
    }

    private func makeChat(id: UUID = UUID(), projectID: UUID) -> ChatThreadRef {
        ChatThreadRef(id: id, projectID: projectID, title: "Chat", createdAt: Date())
    }

    // MARK: - Cache hit

    @Test(.tags(.unit)) func sameProjectAndChat_returnsSameInstance() {
        let provider = makeProvider()
        let project = makeProject()
        let chat = makeChat(projectID: project.id)

        let first = provider.viewModel(for: chat, project: project)
        let second = provider.viewModel(for: chat, project: project)

        #expect(first === second)
    }

    // MARK: - Cache miss: different chat

    @Test(.tags(.unit)) func differentChat_sameProject_returnsNewInstance() {
        let provider = makeProvider()
        let project = makeProject()
        let chatA = makeChat(projectID: project.id)
        let chatB = makeChat(projectID: project.id)

        let vmA = provider.viewModel(for: chatA, project: project)
        let vmB = provider.viewModel(for: chatB, project: project)

        #expect(vmA !== vmB)
    }

    // MARK: - Cache miss: different project

    @Test(.tags(.unit)) func differentProject_sameChat_returnsNewInstance() {
        let provider = makeProvider()
        let projectA = makeProject()
        let projectB = makeProject()

        // Give both projects the same chat ID to stress-test the composite key.
        let sharedChatID = UUID()
        let chatA = makeChat(id: sharedChatID, projectID: projectA.id)
        let chatB = makeChat(id: sharedChatID, projectID: projectB.id)

        let vmA = provider.viewModel(for: chatA, project: projectA)
        let vmB = provider.viewModel(for: chatB, project: projectB)

        #expect(vmA !== vmB)
    }

    // MARK: - Cache grows independently

    @Test(.tags(.unit)) func multipleChats_eachCachedSeparately() {
        let provider = makeProvider()
        let project = makeProject()
        let chat1 = makeChat(projectID: project.id)
        let chat2 = makeChat(projectID: project.id)
        let chat3 = makeChat(projectID: project.id)

        let vm1 = provider.viewModel(for: chat1, project: project)
        let vm2 = provider.viewModel(for: chat2, project: project)
        let vm3 = provider.viewModel(for: chat3, project: project)

        // All three are distinct.
        #expect(vm1 !== vm2)
        #expect(vm2 !== vm3)
        #expect(vm1 !== vm3)

        // Each is still returned from cache on repeat access.
        #expect(provider.viewModel(for: chat1, project: project) === vm1)
        #expect(provider.viewModel(for: chat2, project: project) === vm2)
        #expect(provider.viewModel(for: chat3, project: project) === vm3)
    }
}
