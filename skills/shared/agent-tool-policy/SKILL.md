---
name: agent-tool-policy
description: Agent-aware tool routing and guardrails for native, custom, and MCP tools.
---

# Agent Tool Policy

When handling a request, decide tools in this order:
1. Use app custom tools first for product-specific operations.
2. Use MCP tools for external capabilities (web, APIs, data sources).
3. Use native tools only when policy allows and no higher-priority path exists.

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
