# iOS Companion App — AI Agent Build Brief

Use this document as the exact implementation brief for an iOS coding agent.

## Goal
Build an iOS companion app that pairs with the local Mac sidecar and shows connection state.

This is an MVP focused on pairing + status only.
Do **not** implement remote command execution in this phase.

## Current Backend (Already Implemented)
Base URL (LAN): `http://<mac-ip>:7878`

Available endpoints:

1) `POST /companion/pairing/start`
- Request body: optional `{ "ttlSeconds": number }`
- Response:
```json
{
  "ok": true,
  "code": "123456",
  "expiresAt": "2026-02-25T10:00:00.000Z",
  "qrPayload": "{...json string...}"
}
```

2) `POST /companion/pairing/complete`
- Request body:
```json
{
  "pairingCode": "123456",
  "pairingToken": "optional-token-from-qr",
  "deviceName": "iPhone 16 Pro",
  "devicePublicKey": "base64-or-pem-string"
}
```
- Response:
```json
{
  "ok": true,
  "connected": true,
  "connectedDevice": {
    "id": "abc123...",
    "name": "iPhone 16 Pro",
    "connectedAt": "2026-02-25T10:00:00.000Z",
    "lastSeenAt": "2026-02-25T10:00:00.000Z"
  }
}
```

3) `GET /companion/status`
- Response:
```json
{
  "ok": true,
  "connected": false,
  "connectedDevice": null
}
```
(or same `connectedDevice` object shape as above when connected)

4) `POST /companion/disconnect`
- Response: same shape as `/companion/status`

5) `GET /companion/devices`
- Response:
```json
{
  "ok": true,
  "devices": [
    {
      "id": "abc123...",
      "name": "iPhone 16 Pro",
      "pairedAt": "2026-02-25T10:00:00.000Z",
      "lastSeenAt": "2026-02-25T10:00:00.000Z"
    }
  ]
}
```

6) `DELETE /companion/devices/:id`
- Response: same shape as `/companion/status`

## iOS App Scope (MVP)
Implement only:
- Pair by scanning QR code (primary path)
- Pair by entering 6-digit code manually (fallback)
- Generate/store device keypair in Keychain
- Send `pairing/complete` request
- Show live connection status screen
- Disconnect action
- Basic trusted devices list view

Do not implement:
- Push notifications
- Background sync complexity
- Remote internet relay
- Signed command execution channel
- Chat composer / command execution UI

## Required iOS Screens
1) **Onboarding / Connect**
- Input: Mac base URL (default blank)
- Button: “Check Mac Status” (`GET /health` optional check + `GET /companion/status`)
- CTA: “Scan QR to Pair”
- Secondary CTA: “Enter Code Manually”

2) **QR Pairing Screen**
- Camera scanner for QR
- Parse `qrPayload` JSON from Mac (contains protocol, code, token, expiresAt)
- Auto-fill pairing code + token
- Show countdown to expiry
- “Complete Pairing” action

3) **Manual Pairing Screen**
- 6-digit code input
- Optional Mac URL override (if not set)
- “Complete Pairing” action

4) **Connection Status Screen**
- Connected / disconnected badge
- Device name + connected at
- Pull-to-refresh or refresh button (`GET /companion/status`)
- “Disconnect” button (`POST /companion/disconnect`)

5) **Trusted Devices Screen**
- List from `GET /companion/devices`
- Revoke device with `DELETE /companion/devices/:id`

## Technical Requirements for AI Agent
- Platform: iOS 17+
- UI: SwiftUI
- Concurrency: `async/await`
- Networking: `URLSession`
- Storage: Keychain for private key and selected Mac URL
- Architecture: feature-first with small files (target <200 lines per file)
- Add clear request/response models for every endpoint
- Use one API client module for companion endpoints
- Add lightweight error mapping for network/server/validation errors

## Security Requirements (MVP)
- Generate local keypair on first launch; never transmit private key
- Send only public key to backend
- Validate pairing code format client-side (`^[0-9]{6}$`)
- Require HTTPS only for non-local IPs in future; for now allow LAN HTTP explicitly
- Do not log private key or raw QR token in production logs

## Suggested iOS File Structure
```
ios-companion/
  App/
  Features/
    Pairing/
      Presentation/
      Domain/
      Data/
    Status/
      Presentation/
      Domain/
      Data/
    Devices/
      Presentation/
      Domain/
      Data/
  Shared/
    Networking/
    Crypto/
    Keychain/
    Models/
```

## API Models (Must Match Backend Exactly)
- `CompanionStatusResponse`
- `CompanionDevice`
- `PairingStartResponse`
- `PairingCompleteRequest`
- `DevicesListResponse`

## Acceptance Criteria
- User can pair via QR without typing phone name
- User can pair via manual code entry
- After successful pairing, status screen shows connected device name from server
- Disconnect works and status updates immediately
- Devices list loads and revoke works
- App survives cold restart with keypair still in Keychain
- No file introduced by this implementation exceeds ~200 lines (except app entry if needed)

## QA Checklist
- Invalid code shows user-facing error
- Expired code shows user-facing error and allows retry
- Offline Mac or wrong URL shows retry guidance
- Pairing complete response with `connected=false` is handled safely
- Revoking currently connected device returns app to disconnected state

## Non-Goals (Phase 2)
- Signed command protocol with nonce/replay
- End-to-end encrypted command payloads
- Remote relay for outside-LAN usage
- Background keepalive and silent reconnect workers

---

## Prompt You Can Paste Into an iOS AI Agent
Build an iOS 17+ SwiftUI app called “CopilotForge Companion” using the spec in this document. Implement only MVP pairing + status + trusted devices against the listed endpoints. Use feature-first architecture, async/await, URLSession, and Keychain keypair storage. Keep files small (target under 200 lines). Do not implement command execution or remote relay.
