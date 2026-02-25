import Foundation

struct CompanionConnectionSnapshot: Equatable {
    var connectedDeviceName: String?
    var connectedAt: Date?

    var isConnected: Bool {
        connectedDeviceName != nil
    }
}

struct CompanionPairingSession: Equatable {
    let code: String
}

protocol CompanionConnectionServicing {
    func fetchStatus() async throws -> CompanionConnectionSnapshot
    func startPairing() async throws -> CompanionPairingSession
    func connect(deviceName: String) async throws -> CompanionConnectionSnapshot
    func disconnect() async throws -> CompanionConnectionSnapshot
}
