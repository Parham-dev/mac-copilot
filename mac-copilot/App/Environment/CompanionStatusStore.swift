import Foundation
import SwiftUI
import Combine

@MainActor
final class CompanionStatusStore: ObservableObject {
    enum Status: Equatable {
        case disconnected
        case pairing
        case connected(deviceName: String, connectedAt: Date)
    }

    @Published private(set) var status: Status = .disconnected
    @Published private(set) var pairingCode: String = CompanionStatusStore.generatePairingCode()

    var statusLabel: String {
        switch status {
        case .disconnected:
            return "Disconnected"
        case .pairing:
            return "Pairing"
        case .connected:
            return "Connected"
        }
    }

    var statusColor: Color {
        switch status {
        case .disconnected:
            return .secondary
        case .pairing:
            return .orange
        case .connected:
            return .green
        }
    }

    var isConnected: Bool {
        if case .connected = status {
            return true
        }
        return false
    }

    var connectedDeviceName: String? {
        guard case let .connected(deviceName, _) = status else {
            return nil
        }
        return deviceName
    }

    func startPairing() {
        pairingCode = Self.generatePairingCode()
        status = .pairing
    }

    func markConnected(deviceName: String) {
        status = .connected(deviceName: deviceName, connectedAt: Date())
    }

    func disconnect() {
        status = .disconnected
    }

    private static func generatePairingCode() -> String {
        let value = Int.random(in: 0 ... 999_999)
        return String(format: "%06d", value)
    }
}
