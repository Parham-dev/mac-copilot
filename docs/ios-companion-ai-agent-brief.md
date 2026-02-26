# iOS Companion App — AI Agent Build Brief

Use this document as the exact implementation brief for an iOS coding agent.

## Goal
Build an iOS companion app that can:
- pair to the Mac
- list projects
- list chats per project
- read chat history
- continue chat from mobile

This is a **validation-mode MVP**.
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
  "qrPayload": "{\"protocol\":\"copilotforge-pair-v1\",\"code\":\"123456\",\"token\":\"...\",\"expiresAt\":\"...\"}"
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

7) `GET /companion/projects`
- Requires paired companion + Mac authenticated
- Response:
```json
{
  "ok": true,
  "projects": [
    {
      "id": "project-id",
      "name": "my-project",
      "localPath": "/Users/.../my-project",
      "lastUpdatedAt": "2026-02-25T10:00:00.000Z"
    }
  ]
}
```

8) `GET /companion/projects/:projectId/chats`
- Response:
```json
{
  "ok": true,
  "chats": [
    {
      "id": "chat-id",
      "projectId": "project-id",
      "title": "First prompt title",
      "lastUpdatedAt": "2026-02-25T10:00:00.000Z"
    }
  ]
}
```

9) `GET /companion/chats/:chatId/messages?cursor=0&limit=50`
- Response:
```json
{
  "ok": true,
  "chatId": "chat-id",
  "messages": [
    {
      "id": "message-id",
      "role": "user",
      "text": "hello",
      "createdAt": "2026-02-25T10:00:00.000Z"
    },
    {
      "id": "message-id-2",
      "role": "assistant",
      "text": "hi",
      "createdAt": "2026-02-25T10:00:02.000Z"
    }
  ],
  "nextCursor": "50"
}
```

10) `POST /companion/chats/:chatId/continue` (SSE stream)
- Request body:
```json
{
  "prompt": "continue this",
  "projectPath": "/Users/.../my-project",
  "model": "<selected-model-id>",
  "allowedTools": ["run_in_terminal"]
}
```
- Response is `text/event-stream` with JSON `data:` frames and terminal `[DONE]` frame.

## iOS App Scope (MVP)
Implement only:
- Pair by scanning QR code (primary path)
- Pair by entering 6-digit code manually (fallback)
- Generate/store device keypair in Keychain
- Send `pairing/complete` request
- Show live connection status
- List projects
- List chats in selected project
- Read chat history (cursor pagination)
- Continue existing chat from mobile using SSE stream
- Disconnect action
- Trusted devices list/revoke

Do not implement:
- Push notifications
- Background sync complexity
- Remote internet relay
- Signed command execution channel
- Arbitrary shell/agent command center UI

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

5) **Projects Screen**
- Fetch from `GET /companion/projects`
- Select project to open chats

6) **Chats Screen**
- Fetch from `GET /companion/projects/:projectId/chats`
- Open chat history

7) **Chat Detail Screen**
- Fetch history via `GET /companion/chats/:chatId/messages`
- Load more via `nextCursor`
- Composer to continue chat via `POST /companion/chats/:chatId/continue` SSE

8) **Trusted Devices Screen**
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
- Add SSE parser for `continue` endpoint (`URLSession.bytes` or equivalent stream handling)

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
- `CompanionProject`
- `CompanionChat`
- `CompanionMessage`
- `CompanionMessagesPageResponse`
- `ContinueChatRequest`

## Acceptance Criteria
- User can pair via QR without typing phone name
- User can pair via manual code entry
- After successful pairing, status screen shows connected device name from server
- Projects list loads
- Chats list loads for selected project
- Chat history paginates correctly
- Continue chat stream renders assistant output incrementally
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
- SSE continue call handles `[DONE]` and stream interruption gracefully

## Mac Preflight (Before iOS QA)
Run the companion smoke test on Mac to confirm backend readiness before iOS validation:

```bash
./scripts/companion_validation_smoke.sh
```

Smoke guide and expected outputs:
- `docs/companion-validation-smoke.md`

## Non-Goals (Phase 2)
- Signed command protocol with nonce/replay
- End-to-end encrypted command payloads
- Remote relay for outside-LAN usage
- Background keepalive and silent reconnect workers

---

## Prompt You Can Paste Into an iOS AI Agent
Build an iOS 17+ SwiftUI app called “CopilotForge Companion” using the spec in this document. Implement validation-mode MVP: pairing, status, project list, chat list, chat history pagination, and continue-chat SSE streaming against the listed endpoints. Use feature-first architecture, async/await, URLSession, and Keychain keypair storage. Keep files small (target under 200 lines). Do not implement remote relay or signed command protocol yet.
