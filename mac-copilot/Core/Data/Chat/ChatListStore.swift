import Foundation

@MainActor
protocol ChatListStore {
    func loadChats() -> [String]
    func saveChats(_ chats: [String])
}
