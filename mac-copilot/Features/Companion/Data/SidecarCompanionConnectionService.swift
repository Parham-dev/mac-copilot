import Foundation

@MainActor
final class SidecarCompanionConnectionService: CompanionConnectionServicing {
    private let client: SidecarCompanionClient

    init(client: SidecarCompanionClient) {
        self.client = client
    }

    func fetchStatus() async throws -> CompanionConnectionSnapshot {
        let response = try await client.fetchStatus()
        return mapStatus(response)
    }

    func startPairing() async throws -> CompanionPairingSession {
        let response = try await client.startPairing()
        let expiresAt = ISO8601DateFormatter().date(from: response.expiresAt) ?? Date().addingTimeInterval(300)
        return CompanionPairingSession(code: response.code, qrPayload: response.qrPayload, expiresAt: expiresAt)
    }

    func disconnect() async throws -> CompanionConnectionSnapshot {
        let response = try await client.disconnect()
        return mapStatus(response)
    }

    private func mapStatus(_ response: SidecarCompanionStatusResponse) -> CompanionConnectionSnapshot {
        guard response.connected, let device = response.connectedDevice else {
            return CompanionConnectionSnapshot(connectedDeviceName: nil, connectedAt: nil)
        }

        let connectedAt = ISO8601DateFormatter().date(from: device.connectedAt)
        return CompanionConnectionSnapshot(connectedDeviceName: device.name, connectedAt: connectedAt)
    }
}
