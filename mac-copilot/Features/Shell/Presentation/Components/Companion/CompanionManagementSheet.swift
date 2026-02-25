import SwiftUI

struct CompanionManagementSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var companionStatusStore: CompanionStatusStore
    @State private var deviceName = "Parham’s iPhone"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iOS Companion")
                        .font(.title2.weight(.semibold))
                    Text("Pair your iPhone to create chats, sessions, and projects from mobile.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    isPresented = false
                }
            }

            statusCard

            Divider()

            if companionStatusStore.isConnected {
                connectedSection
            } else {
                pairingSection
            }

            if companionStatusStore.isBusy {
                ProgressView("Updating companion state…")
                    .font(.callout)
            }

            if let lastErrorMessage = companionStatusStore.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text("What’s missing for full companion support")
                    .font(.headline)
                Text("• Bonjour discovery and local bridge endpoint")
                Text("• Device key pairing and revocation")
                Text("• Signed command protocol and replay protection")
                Text("• Remote relay for outside-LAN access (phase 2)")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .task {
            await companionStatusStore.refreshStatus()
        }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(companionStatusStore.statusColor)
                .frame(width: 10, height: 10)
            Text("Status: \(companionStatusStore.statusLabel)")
                .font(.subheadline.weight(.medium))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pair new device")
                .font(.headline)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pairing Code")
                        .font(.subheadline.weight(.medium))
                    Text(companionStatusStore.pairingCode)
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 10) {
                        Button("Generate New Code") {
                            Task {
                                await companionStatusStore.startPairing()
                            }
                        }
                        .disabled(companionStatusStore.isBusy)

                        TextField("Device name", text: $deviceName)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 180)

                        Button("Connect") {
                            Task {
                                await companionStatusStore.connect(deviceName: deviceName)
                            }
                        }
                        .disabled(companionStatusStore.isBusy)
                    }
                }

                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 72, weight: .regular))
                        .frame(width: 120, height: 120)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("QR Placeholder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected device")
                .font(.headline)

            HStack {
                Image(systemName: "iphone")
                    .foregroundStyle(.secondary)
                Text(companionStatusStore.connectedDeviceName ?? "Unknown Device")
                    .font(.body.weight(.medium))
                Spacer()
                Button("Disconnect", role: .destructive) {
                    Task {
                        await companionStatusStore.disconnect()
                    }
                }
                .disabled(companionStatusStore.isBusy)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
