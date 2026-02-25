# Chat Session History Architecture

This document explains how chat history is handled between the macOS app and the sidecar.

## Current Model

CopilotForge now uses **one Copilot SDK session per app chat thread**.

High-level flow:
1. Swift chat UI sends prompt with `chatID`.
2. Sidecar maps that `chatID` to a deterministic SDK `sessionId`.
3. Sidecar uses `resumeSession(sessionId, ...)` when available.
4. If resume fails, sidecar creates a new session with the same `sessionId`.
5. Prompt is sent to that thread-bound session.

This prevents cross-thread context leakage and keeps chat context scoped to each app chat.

## Why This Is Best Practice

- Avoids manually replaying full message history every request.
- Uses SDK-native session persistence and lifecycle.
- Keeps context management stable as conversations grow.
- Reduces payload size and prompt duplication overhead.

## Infinite Sessions

Sidecar enables SDK `infiniteSessions` for compaction support.

Benefits:
- Large conversations are compacted automatically.
- Context-window pressure is handled by SDK internals.
- History continuity remains tied to session identity.

## Session Keys

- Preferred key: app `chatID`.
- Fallback key: project path (for compatibility scenarios).
- Last fallback: `default`.

The sidecar derives a deterministic `sessionId` from the key, e.g. `copilotforge-<sanitized-key>`.

## Operational Notes

- Switching model/project/tools for the same chat may recreate that chat’s in-memory session object, but it remains thread-scoped.
- Sidecar restart does not imply thread history loss when `resumeSession` succeeds.
- Local app message persistence remains in SwiftData for UI rendering and metadata.

## Files Involved

- Swift prompt pipeline:
  - `mac-copilot/Features/Chat/Presentation/ChatViewModel.swift`
  - `mac-copilot/Features/Chat/Domain/UseCases/SendPromptUseCase.swift`
  - `mac-copilot/Features/Chat/Domain/Contracts/PromptStreamingRepository.swift`
  - `mac-copilot/Features/Chat/Data/CopilotPromptRepository.swift`
  - `mac-copilot/Features/Chat/Data/CopilotAPIService.swift`
  - `mac-copilot/Features/Chat/Data/CopilotPromptStreamClient.swift`

- Sidecar session management:
  - `sidecar/src/index.ts`
  - `sidecar/src/copilot.ts`
