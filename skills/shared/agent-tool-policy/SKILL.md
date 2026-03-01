---
name: agent-tool-policy
description: Agent-aware tool routing and guardrails for native, custom, and MCP tools.
---

# Agent Tool Policy

When handling a request, follow policy constraints without forcing fixed tool order.

Rules:
- Respect per-agent allowed tool set.
- Deny tools outside the agent policy.
- Log tool decision path (`custom|mcp|native`) per run.
- Never silently fallback to broader tool scopes.
- If strict mode is enabled, block native fallback.

Output behavior:
- Explain blocked tools briefly.
- Continue with the next allowed tool path.
- Return actionable diagnostics when no tool path is valid.
