import Foundation
import Combine

struct ChatTitleDidUpdateEvent {
    let chatID: UUID
    let title: String
}

struct ChatResponseDidFinishEvent {
    let projectPath: String
}

@MainActor
final class ChatEventsStore {
    private let chatTitleDidUpdateSubject = PassthroughSubject<ChatTitleDidUpdateEvent, Never>()
    private let chatResponseDidFinishSubject = PassthroughSubject<ChatResponseDidFinishEvent, Never>()

    var chatTitleDidUpdate: AnyPublisher<ChatTitleDidUpdateEvent, Never> {
        chatTitleDidUpdateSubject.eraseToAnyPublisher()
    }

    var chatResponseDidFinish: AnyPublisher<ChatResponseDidFinishEvent, Never> {
        chatResponseDidFinishSubject.eraseToAnyPublisher()
    }

    func publishChatTitleDidUpdate(chatID: UUID, title: String) {
        chatTitleDidUpdateSubject.send(ChatTitleDidUpdateEvent(chatID: chatID, title: title))
    }

    func publishChatResponseDidFinish(projectPath: String) {
        chatResponseDidFinishSubject.send(ChatResponseDidFinishEvent(projectPath: projectPath))
    }
}