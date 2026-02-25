import Foundation

actor InMemoryCompanionConnectionService: CompanionConnectionServicing {
    private var snapshot = CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil)

    func fetchStatus() async throws -> CompanionConnectionSnapshot {
        snapshot
    }

    func startPairing() async throws -> CompanionPairingSession {
        try await Task.sleep(nanoseconds: 200_000_000)
        let value = Int.random(in: 0 ... 999_999)
        let code = String(format: "%06d", value)
        return CompanionPairingSession(
            code: code,
            qrPayload: "{\"protocol\":\"copilotforge-pair-v1\",\"code\":\"\(code)\"}",
            expiresAt: Date().addingTimeInterval(300)
        )
    }

    func disconnect() async throws -> CompanionConnectionSnapshot {
        try await Task.sleep(nanoseconds: 150_000_000)
        snapshot = CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil)
        return snapshot
    }
}
