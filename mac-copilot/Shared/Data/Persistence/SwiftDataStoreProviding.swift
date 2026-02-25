import SwiftData

@MainActor
protocol SwiftDataStoreProviding {
    var container: ModelContainer { get }
    var context: ModelContext { get }
}
