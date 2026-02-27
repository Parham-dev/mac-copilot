import Foundation
import Combine
import Testing
@testable import mac_copilot

@MainActor
struct ChatEventsStoreTests {
    @Test(.tags(.unit)) func publishChatTitleDidUpdate_emitsEvent() async throws {
        let store = ChatEventsStore()
        let chatID = UUID()
        var received: ChatTitleDidUpdateEvent?

        var cancellables = Set<AnyCancellable>()
        store.chatTitleDidUpdate.sink { received = $0 }.store(in: &cancellables)

        store.publishChatTitleDidUpdate(chatID: chatID, title: "New Title")

        #expect(received?.chatID == chatID)
        #expect(received?.title == "New Title")
    }

    @Test(.tags(.unit)) func publishChatResponseDidFinish_emitsEvent() async throws {
        let store = ChatEventsStore()
        var received: ChatResponseDidFinishEvent?

        var cancellables = Set<AnyCancellable>()
        store.chatResponseDidFinish.sink { received = $0 }.store(in: &cancellables)

        store.publishChatResponseDidFinish(projectPath: "/tmp/project")

        #expect(received?.projectPath == "/tmp/project")
    }

    @Test(.tags(.unit, .regression)) func lateSubscriber_doesNotReceivePreviousEvents() {
        let store = ChatEventsStore()
        let chatID = UUID()

        store.publishChatTitleDidUpdate(chatID: chatID, title: "Old Title")

        var received: ChatTitleDidUpdateEvent?
        var cancellables = Set<AnyCancellable>()
        store.chatTitleDidUpdate.sink { received = $0 }.store(in: &cancellables)

        #expect(received == nil)
    }

    @Test(.tags(.unit)) func publishChatTitleDidUpdate_multipleEventsReceivedInOrder() {
        let store = ChatEventsStore()
        var receivedTitles: [String] = []

        var cancellables = Set<AnyCancellable>()
        store.chatTitleDidUpdate.sink { receivedTitles.append($0.title) }.store(in: &cancellables)

        store.publishChatTitleDidUpdate(chatID: UUID(), title: "First")
        store.publishChatTitleDidUpdate(chatID: UUID(), title: "Second")
        store.publishChatTitleDidUpdate(chatID: UUID(), title: "Third")

        #expect(receivedTitles == ["First", "Second", "Third"])
    }
}
