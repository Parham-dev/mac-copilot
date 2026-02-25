import Foundation

actor InMemoryCompanionConnectionService: CompanionConnectionServicing {
    private var snapshot = CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil)

    func fetchStatus() async throws -> CompanionConnectionSnapshot {
        snapshot
    }

    func startPairing() async throws -> CompanionPairingSession {
        try await Task.sleep(nanoseconds: 200_000_000)
        let value = Int.random(in: 0 ... 999_999)
        return CompanionPairingSession(code: String(format: "%06d", value))
    }

    func connect(deviceName: String) async throws -> CompanionConnectionSnapshot {
        try await Task.sleep(nanoseconds: 250_000_000)
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "iPhone" : trimmed
        snapshot = CompanionConnectionSnapshot(connectedDeviceName: resolvedName, connectedAt: Date())
        return snapshot
    }

    func disconnect() async throws -> CompanionConnectionSnapshot {
        try await Task.sleep(nanoseconds: 150_000_000)
        snapshot = CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil)
        return snapshot
    }
}
