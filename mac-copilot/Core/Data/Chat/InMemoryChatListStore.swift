import Foundation

@MainActor
final class InMemoryChatListStore: ChatListStore {
    private var chats: [String]

    init(seedChats: [String] = ["New Project", "Landing Page", "CRM Dashboard"]) {
        self.chats = seedChats
    }

    func loadChats() -> [String] {
        chats
    }

    func saveChats(_ chats: [String]) {
        self.chats = chats
    }
}
