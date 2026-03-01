---
name: agent-json-contract
description: Enforce schema-safe JSON outputs for agent runs and repair stage behavior.
---

# Agent JSON Contract

When agent output must match schema:
1. Return only valid JSON with required keys.
2. Avoid markdown fences and extra prose.
3. Preserve semantic meaning during repair.

If initial output is invalid:
- Run repair stage without tool access.
- Convert text to strict JSON matching the contract.
- Keep `sourceMetadata` fields present.

Quality gates:
- Parse result before marking run completed.
- Emit diagnostics when parse fails.
- Keep warnings concise and actionable.
