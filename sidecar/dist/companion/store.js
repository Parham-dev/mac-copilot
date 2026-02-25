import { createHash, randomUUID } from "node:crypto";
export class CompanionStore {
    pairingSession = null;
    connectedDeviceId = null;
    devices = new Map();
    status() {
        const device = this.connectedDeviceId ? this.devices.get(this.connectedDeviceId) ?? null : null;
        return {
            connected: device !== null,
            connectedDevice: device
                ? {
                    id: device.id,
                    name: device.name,
                    connectedAt: device.pairedAt,
                    lastSeenAt: device.lastSeenAt,
                }
                : null,
        };
    }
    startPairing(ttlSeconds = 300) {
        const code = String(Math.floor(Math.random() * 1_000_000)).padStart(6, "0");
        const token = randomUUID();
        const expiresAt = Date.now() + ttlSeconds * 1_000;
        this.pairingSession = { code, token, expiresAt };
        const qrPayload = JSON.stringify({
            protocol: "copilotforge-pair-v1",
            code,
            token,
            expiresAt: new Date(expiresAt).toISOString(),
        });
        return {
            code,
            expiresAt: new Date(expiresAt).toISOString(),
            qrPayload,
        };
    }
    completePairing(input) {
        const session = this.pairingSession;
        if (!session) {
            throw new Error("No active pairing session");
        }
        if (Date.now() > session.expiresAt) {
            this.pairingSession = null;
            throw new Error("Pairing session expired");
        }
        const pairingCode = String(input.pairingCode ?? "").trim();
        if (pairingCode !== session.code) {
            throw new Error("Invalid pairing code");
        }
        const providedToken = String(input.pairingToken ?? "").trim();
        if (providedToken.length > 0 && providedToken !== session.token) {
            throw new Error("Invalid pairing token");
        }
        const key = String(input.devicePublicKey ?? "").trim();
        if (!key) {
            throw new Error("Missing device public key");
        }
        const name = String(input.deviceName ?? "iPhone").trim() || "iPhone";
        const now = new Date().toISOString();
        const id = createHash("sha256").update(key).digest("hex").slice(0, 16);
        this.devices.set(id, {
            id,
            name,
            publicKey: key,
            pairedAt: now,
            lastSeenAt: now,
        });
        this.connectedDeviceId = id;
        this.pairingSession = null;
        return this.status();
    }
    disconnect() {
        this.connectedDeviceId = null;
        return this.status();
    }
    listDevices() {
        return Array.from(this.devices.values()).map((device) => ({
            id: device.id,
            name: device.name,
            pairedAt: device.pairedAt,
            lastSeenAt: device.lastSeenAt,
        }));
    }
    revokeDevice(id) {
        const normalizedId = String(id).trim();
        if (!normalizedId) {
            throw new Error("Missing device id");
        }
        this.devices.delete(normalizedId);
        if (this.connectedDeviceId === normalizedId) {
            this.connectedDeviceId = null;
        }
        return this.status();
    }
}
