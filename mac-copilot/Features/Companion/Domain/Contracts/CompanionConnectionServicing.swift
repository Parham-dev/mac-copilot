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
    let qrPayload: String
    let expiresAt: Date
}

protocol CompanionConnectionServicing {
    func fetchStatus() async throws -> CompanionConnectionSnapshot
    func startPairing() async throws -> CompanionPairingSession
    func disconnect() async throws -> CompanionConnectionSnapshot
}
