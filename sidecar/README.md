# Sidecar (Node Runtime)

This folder contains the local Copilot sidecar used by the macOS app.

## Milestone Workflow

### Milestone 1 — TypeScript Scaffold
- Source files in `src/`
- Build output in `dist/`
- Runtime launches from `dist/index.js`

### Milestone 2 — Portability Hardening
- Runtime diagnostics endpoint: `GET /doctor`
- Node compatibility requirement: `node:sqlite` support (Node 22+)
- Sidecar startup prefers compatible runtime and avoids stale incompatible process reuse

### Milestone 3 — Packaging Validation
Use:

```bash
npm run check
```

This runs:
1. `npm run typecheck`
2. `npm run build`
3. `npm run doctor`

## Commands

```bash
npm install
npm run typecheck
npm run build
npm run doctor
npm run check
npm run start
npm run start:dist
```

## Runtime Notes (Small but Important)

- The app sidecar now runs from `dist/index.js`.
- Canonical source entry is `src/index.ts`.
- Copilot runtime logic lives under `src/copilot/` (for example `copilot.ts`, `copilotPromptStreaming.ts`, `copilotSessionManager.ts`).
- If you hit local runtime issues, run `npm run check` first.
- If an old sidecar is still bound to port `7878`, stop it and restart from `sidecar/`.

## Runtime Environment Flags

- `COPILOTFORGE_SKILL_DIRECTORIES` — comma-separated skill parent directories for SDK `skillDirectories` (example: `./skills,/opt/copilot/skills`).
- `COPILOTFORGE_DISABLED_SKILLS` — comma-separated skill names mapped to SDK `disabledSkills` (example: `experimental-feature,deprecated-tool`).
- `COPILOTFORGE_BACKGROUND_COMPACTION_THRESHOLD` — overrides infinite session `backgroundCompactionThreshold`.
- `COPILOTFORGE_BUFFER_EXHAUSTION_THRESHOLD` — overrides infinite session `bufferExhaustionThreshold`.
- `COPILOTFORGE_OTEL_ENABLED=1` — enables optional OpenTelemetry span emission for prompt/tool lifecycle.
- `COPILOTFORGE_ENABLE_FETCH_MCP` — enable/disable Fetch MCP server wiring (default enabled).
- `COPILOTFORGE_FETCH_MCP_COMMAND` — command used to start Fetch MCP server (default `uvx`).
- `COPILOTFORGE_FETCH_MCP_ARGS` — command arguments for Fetch MCP server (default `mcp-server-fetch`).
- `COPILOTFORGE_FETCH_MCP_TIMEOUT_MS` — startup timeout for Fetch MCP server (default `30000`).
- `COPILOTFORGE_REQUIRE_AGENT_SKILLS` — controls strict skill requirement for agent runs; default is enabled (`true`). Set `0`/`false` to relax.

Fetch MCP note:
- The sidecar starts Fetch MCP server automatically through `mcpServers`.
- Default launch uses `uvx mcp-server-fetch`.
- URL Summariser strict behavior is controlled by agent skill/policy (`url-fetch`) rather than environment flags.
- In strict mode, URL Summariser narrows its allowed tool list to MCP `fetch` only.
- App runtime auto-uses `~/.local/bin/uvx` for `COPILOTFORGE_FETCH_MCP_COMMAND` when available (unless you explicitly set the variable).

Fetch MCP troubleshooting:
- If strict mode is enabled and logs show `web_fetch` denied while `fetch` is never called, the MCP server likely failed to start or expose tools.
- Verify command availability in the app runtime environment (GUI apps may not inherit your shell PATH):
	- Prefer an absolute command path via `COPILOTFORGE_FETCH_MCP_COMMAND`.
	- Confirm the command runs manually with the same args.
- Keep `tools: ["*"]` in MCP config (already set by the sidecar).

Skills loading notes:
- If `COPILOTFORGE_SKILL_DIRECTORIES` is unset, sidecar auto-discovers common local paths relative to runtime cwd (`./skills`, `../skills`, `../../skills`).
- Skills follow MCP SDK format: `<skill-folder>/SKILL.md` under a parent skills directory.
- Recommended scalable layout:
	- `skills/shared/<skill-name>/SKILL.md`
	- `skills/agents/<agent-id>/<skill-name>/SKILL.md`
- For agent runs, sidecar prefers scoped directories (`shared` + `agents/<agent-id>`) when available.
- Agent-provided skill names are applied by disabling non-selected skills in the active scoped directories.
- To disable specific skills at runtime, use `COPILOTFORGE_DISABLED_SKILLS=name1,name2`.
- For app packaging, include the skills directory in app resources if you want skills available outside local dev.

Probe strict/default tool-path behavior:
- Run `scripts/probe_tool_path.sh` from repo root.
- It executes two `/prompt` runs (`strict-fetch-mcp`, `default`) and prints inferred `tool_path` + `fallback_used` from SSE tool events.
- Raw SSE captures are written to `/tmp/copilotforge-probe-strict.sse` and `/tmp/copilotforge-probe-default.sse`.

## Release vs Debug Node Policy

- `Debug`: resolver prefers bundled Node but can fall back to compatible system Node for local development.
- `Release`: resolver is bundled-only (no system `PATH` fallback).
- Release packaging should copy these into app resources:
	- `node` executable
	- `sidecar/dist`
	- `sidecar/node_modules`
	- `skills` (if skill-based behavior should be available in packaged builds)

An Xcode build phase script can automate this copy step from the repository sidecar folder.

## Doctor Output

`npm run doctor` validates:
- current Node version and executable path
- `node:sqlite` support
- `@github/copilot-sdk` presence in `node_modules`

It exits non-zero when runtime is not compatible.
