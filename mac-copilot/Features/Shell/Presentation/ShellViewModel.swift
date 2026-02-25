import Foundation
import Combine

@MainActor
final class ShellViewModel: ObservableObject {
    enum SidebarItem: Hashable {
        case profile
        case chat(String)
    }

    enum ContextTab: String, CaseIterable, Identifiable {
        case preview
        case git

        var id: String { rawValue }
    }

    @Published private(set) var chats: [String]
    @Published var selectedItem: SidebarItem?
    @Published var selectedContextTab: ContextTab = .preview

    private let chatListStore: ChatListStore

    init(chatListStore: ChatListStore) {
        self.chatListStore = chatListStore
        self.chats = chatListStore.loadChats()
        self.selectedItem = chats.first.map { .chat($0) }
    }

    func createChat() {
        let title = "Chat \(chats.count + 1)"
        chats.append(title)
        chatListStore.saveChats(chats)
        selectedItem = .chat(title)
    }
}
