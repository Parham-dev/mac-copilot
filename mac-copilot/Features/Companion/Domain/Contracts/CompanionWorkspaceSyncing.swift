import Foundation

@MainActor
protocol CompanionWorkspaceSyncing {
    func syncWorkspaceSnapshot() async
}
