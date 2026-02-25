# iOS Companion Architecture

This document defines how the paid iOS companion app can securely control the macOS CopilotForge app.

## Why this exists

CopilotForge on macOS is free for any GitHub user (subject to GitHub Copilot limits). The iOS companion is a separate paid product focused on remote control and lightweight mobile workflows.

The architecture must:
- keep the macOS repo public and secret-safe,
- avoid exposing GitHub tokens to iOS,
- ship quickly with low infrastructure risk,
- support remote usage outside office/home networks.

## Product model

- macOS app: free core experience.
- iOS companion app: paid app/SKU.
- Footer CTA in macOS shell: **Upgrade** (not Update) for premium/companion onboarding.

## Security baseline (all phases)

1. Never send raw GitHub Copilot token to iOS.
2. Mac remains the execution authority (iOS only requests actions).
3. Every device pairing is explicit and revocable.
4. Commands are authenticated, timestamped, and replay-protected.
5. Public repo must not contain secrets, certificates, private keys, or deploy credentials.

## Public repo hygiene policy

Required controls:
- `.gitignore` covers build artifacts and env files.
- Add explicit ignore for DMGs: `dist/*.dmg`.
- CI secret scanning (for example, gitleaks/trufflehog).
- Push-size guard (fail > 90MB before GitHub hard limit at 100MB).
- Branch protection requiring CI checks.

Operational rule:
- production credentials only in CI/CD secret store or local keychain, never in git.

---

## Phase 1 (MVP): Local network companion (LAN)

Phase 1 is the fastest, lowest-risk shipping path.

### Scope

Supported from iOS:
- create new chat,
- create new session/thread,
- create new project,
- send prompt to selected thread,
- list basic project/chat state.

Out of scope:
- full preview/runtime streaming,
- remote internet access,
- multi-user collaboration.

### High-level design

- Mac app hosts a local Companion Bridge service (localhost + LAN bind when enabled).
- iOS app discovers Mac via mDNS/Bonjour.
- User pairs once using QR or short code.
- iOS sends signed command envelopes; Mac executes and returns status/results.

### Components

Mac:
- `CompanionBridgeServer` (HTTP + WebSocket)
- `CompanionPairingService`
- `CompanionCommandRouter`
- `CompanionDeviceStore` (macOS Keychain + local metadata)

iOS:
- `CompanionDiscoveryClient` (Bonjour)
- `PairingFlowViewModel`
- `CompanionAPIClient`
- `SecureKeyStore` (iOS Keychain)

### Pairing flow (recommended)

1. User taps **Upgrade** on macOS and starts companion pairing.
2. Mac generates one-time pairing challenge (TTL 5 minutes), displayed as QR + 6-digit fallback code.
3. iOS scans QR / enters code and submits device public key + app metadata.
4. Mac verifies challenge, stores trusted device record, returns session bootstrap token.
5. iOS stores token + keys in Keychain.

### Transport and protocol

- Discovery: Bonjour service name `copilotforge-companion._tcp`.
- Commands: HTTPS JSON over local network.
- Live updates: WebSocket (optional in phase 1, can be polling first).

Command envelope:
- `commandId` (UUID)
- `issuedAt`
- `expiresAt`
- `deviceId`
- `nonce`
- `signature`
- `payload` (typed command)

Replay protection:
- reject reused nonce,
- reject expired envelopes,
- idempotency on `commandId`.

### Authorization model

Per device permissions:
- `chat.create`
- `chat.send`
- `project.create`
- `session.create`

Mac can later expose per-device toggles in settings.

### Error handling UX

iOS states:
- Mac offline,
- Not paired,
- Pairing expired,
- Permission denied,
- Command timeout,
- Version mismatch.

Mac states:
- Companion disabled,
- Too many failed auth attempts,
- Device revoked.

### Versioning

- Add protocol version header: `X-CopilotForge-Companion-Version`.
- Fail gracefully with `426 Upgrade Required` style response for incompatible clients.

### Observability

Log categories:
- pairing events,
- auth failures,
- command latency,
- command result code.

Do not log prompt content by default in production.

### Phase 1 implementation checklist

- [ ] Add companion feature flag in macOS app settings.
- [ ] Build Bonjour discovery endpoint.
- [ ] Implement pairing challenge + trusted device store.
- [ ] Implement command router for 4 MVP commands.
- [ ] Add request signing + nonce replay protection.
- [ ] Add iOS keychain-backed session store.
- [ ] Add revocation UI on macOS.
- [ ] Add protocol version gate and compatibility checks.

### Phase 1 test matrix

Functional:
- pair/unpair,
- send command happy path,
- duplicate command idempotency,
- revoke device then retry.

Security:
- invalid signature,
- expired envelope,
- nonce replay.

Network:
- same LAN,
- Wi-Fi switch,
- Mac sleep/wake.

---

## Phase 2: Remote access outside LAN

To work outside office/home, add one of:

### Option A (recommended for product): Cloud relay

- iOS and Mac both maintain outbound TLS sessions to relay.
- Relay brokers encrypted command/result envelopes.
- Mac still executes all privileged operations.

Pros:
- best user experience,
- works through NAT/firewalls,
- controlled product UX.

Cons:
- infrastructure + ops cost,
- abuse/rate-limit handling needed.

Minimum relay requirements:
- short-lived auth tokens,
- per-device revocation,
- rate limits,
- audit trail metadata (no secrets/prompt body retention by default).

### Option B: VPN mesh (fast operational path)

- Use managed mesh like Tailscale.
- iOS and Mac communicate over private overlay network.

Pros:
- no relay backend initially,
- strong security.

Cons:
- extra user setup friction,
- less consumer-friendly.

---

## Phase 3 (optional)

- preview/runtime controls,
- rich push notifications,
- multi-mac account routing,
- enterprise policy controls.

---

## Recommended rollout strategy

1. Ship Phase 1 LAN in paid iOS app beta.
2. Validate command model and device trust UX.
3. Add remote relay for paid tier once command reliability is stable.
4. Add advanced controls after telemetry confirms base usage.

## Decision summary

- Yes, companion outside office is possible.
- LAN-only is a deliberate first phase, not a final architecture.
- Remote capability requires relay or VPN overlay.
- For product quality, relay-backed Phase 2 is the recommended long-term path.
