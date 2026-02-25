# Troubleshooting

## Build fails with `Sandbox: rsync deny`

Cause:
- Xcode user script sandboxing blocked the sidecar copy build phase.

Fix:
- Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` for app target build configurations.

## App cannot start sidecar in Release

Check:
- `Contents/Resources/node` exists and is executable
- `Contents/Resources/sidecar/dist/index.js` exists
- `Contents/Resources/sidecar/node_modules/@github/copilot-sdk` exists

## Sidecar reports incompatible Node (`node:sqlite`)

Cause:
- Runtime Node is too old or missing required built-ins.

Fix:
- Use Node 22+ on build machine (or set `COPILOTFORGE_NODE_PATH` to a compatible binary).
- Rebuild and re-export the app.

## Port 7878 appears busy

Cause:
- stale sidecar process from previous run.

Fix:
```bash
pkill -f '/path/to/sidecar/index.js' || true
lsof -nP -iTCP:7878 -sTCP:LISTEN || true
```

## Sign-in succeeds but prompt fails

Check:
- Sidecar `/health` and `/doctor` are healthy.
- Bundled `node_modules` includes SDK dependencies.
- App has network access to GitHub endpoints.
