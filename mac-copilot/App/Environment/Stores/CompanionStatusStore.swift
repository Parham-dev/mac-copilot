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
    @Published private(set) var pairingCode: String = "------"
    @Published private(set) var pairingQRCodePayload: String?
    @Published private(set) var pairingExpiresAt: Date?
    @Published private(set) var isBusy = false
    @Published private(set) var lastErrorMessage: String?

    private let service: CompanionConnectionServicing
    private var latestOperationID: Int = 0

    init(service: CompanionConnectionServicing) {
        self.service = service
    }

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

    func refreshStatus() async {
        await runOperation { operationID in
            let snapshot = try await service.fetchStatus()
            guard operationID == latestOperationID else { return }
            apply(snapshot)
        }
    }

    func startPairing() async {
        await runOperation { operationID in
            let session = try await service.startPairing()
            guard operationID == latestOperationID else { return }
            pairingCode = session.code
            pairingQRCodePayload = session.qrPayload
            pairingExpiresAt = session.expiresAt
            status = .pairing
        }
    }

    func disconnect() async {
        await runOperation { operationID in
            let snapshot = try await service.disconnect()
            guard operationID == latestOperationID else { return }
            apply(snapshot)
            pairingCode = "------"
            pairingQRCodePayload = nil
            pairingExpiresAt = nil
        }
    }

    private func runOperation(_ operation: (_ operationID: Int) async throws -> Void) async {
        latestOperationID += 1
        let operationID = latestOperationID
        isBusy = true
        lastErrorMessage = nil
        defer {
            if operationID == latestOperationID {
                isBusy = false
            }
        }

        do {
            try await operation(operationID)
        } catch {
            if operationID == latestOperationID {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func apply(_ snapshot: CompanionConnectionSnapshot) {
        if snapshot.isConnected {
            status = .connected(deviceName: snapshot.connectedDeviceName ?? "iPhone", connectedAt: snapshot.connectedAt ?? Date())
        } else {
            status = .disconnected
        }
    }
}
