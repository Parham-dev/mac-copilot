import Foundation
import Combine

@MainActor
final class CompanionEnvironment: ObservableObject {
    let companionStatusStore: CompanionStatusStore

    init(companionStatusStore: CompanionStatusStore) {
        self.companionStatusStore = companionStatusStore
    }
}
