# CopilotForge Apps Platform (Product Direction)

This document captures the next product direction for CopilotForge:

- Move from generic “workflow” framing to **Apps for non-technical users**
- Keep technical complexity hidden behind AI and guardrails and agent Skills folder.
- Use the same Copilot brain/tooling stack under the hood, Native tools and Skills or custom one if needed.

It is intentionally product-first and not tied to a specific implementation.

## Core Concept

Each app starts from a trusted **Base Template** and can be customized by AI for each user.

- Base Template (owned by platform):
  - required inputs/form schema
  - default system prompt and tool permissions
  - output shape and quality checks
  - non-editable guardrails
  - an agent skill folder for that app. agent aksill gets update absed on user custimsation.
  - Custom native tool and agent tool if required for those flows
- User Customization (owned by user):
  - tone, audience, format preferences
  - app-specific behavior adjustments through natural language
  - “make this app work like X for my use case”

This avoids exposing technical abstractions like tools, dependencies, or prompt internals.

## Non-Technical UX Model

Simple flow:

1. Pick an app from catalog
2. Enter inputs in form
3. Generate output
4. Copy/export result

For app editing:

- **Preview**: draft edits + test runs
- **Live**: currently published app behavior
- **Publish**: promote preview revision to live
- **Rollback**: restore prior live revision

All internals remain hidden.

## Versioning Model

Every app change is versioned.

- Immutable revision history
- Live pointer to a published revision
- Preview pointer to an editable draft revision
- One-click rollback to previous live revision

This keeps app evolution safe for non-technical users.

## Sidecar Tool-Library Direction

Sidecar should expose a discoverable local **tool library** so AI can compose functionality without requiring users to install dependencies manually.

Goals:

- AI discovers available capabilities from sidecar
- Stable tool contracts (input/output schema)
- Guarded execution with allowlists and safety checks
- Clear execution traces for debugging and trust

## Models and Specialized Capabilities

Default path: Copilot-backed model for most app tasks.

Optional routed capabilities:

- image generation via Replicate (for apps that need visual assets)
- specialized summarization/retrieval paths when app requires it

Users should see simple quality/speed choices, not model internals.

## Monetization Split (Current Direction)

- **Mac app**: free core experience
- **iOS Companion**: Pro-only
- **Advanced capabilities** (higher limits, premium app packs, image generation): Pro

This preserves a low-friction entry while funding advanced features.

## Example Apps

- Social Media Post Builder
  - inputs: topic, URL, resources, target platforms, post count
  - outputs: channel-specific post drafts + copy blocks
- News Aggregator Brief
  - inputs: sources, timeframe, audience, style
  - outputs: structured digest cards + copy-ready summary

## Guardrails and Trust

Guardrails are first-class and non-optional:

- schema validation before publish
- safety/compliance checks per app type
- source/citation policy for research/news apps
- safe fallback behavior when tools/models fail

## Near-Term Product Milestones

1. Define app template schema (inputs, outputs, guardrails, tool scope)
2. Add preview/live and revision timeline UX
3. Build AI customization flow for app variants
4. Integrate sidecar tool-library discovery
5. Add iOS companion access policy for Pro users
