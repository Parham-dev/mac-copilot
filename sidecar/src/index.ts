import express from "express";
import { startClient, isAuthenticated, clearSession, getCopilotReport, listAvailableModels } from "./copilot/copilot.js";
import { pollDeviceFlow, startDeviceFlow, fetchTokenScopes } from "./auth.js";
import { registerCompanionRoutes } from "./companion/routes.js";
import { registerPromptRoute } from "./promptRoute.js";
import { buildDoctorReport, isHealthySidecarAlreadyRunning, resolvedStartupURLs } from "./sidecarRuntime.js";

const app = express();
app.use(express.json());
registerCompanionRoutes(app);
const processStartedAtMs = Date.now();

let lastOAuthScope: string | null = null;

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "copilotforge-sidecar",
    nodeVersion: process.version,
    nodeExecPath: process.execPath,
    processStartedAtMs,
  });
});

app.get("/auth/status", (_req, res) => {
  res.json({ ok: true, authenticated: isAuthenticated() });
});

app.get("/doctor", async (_req, res) => {
  const report = await buildDoctorReport();
  res.status(report.ok ? 200 : 500).json(report);
});

app.get("/copilot/report", async (_req, res) => {
  try {
    const report = {
      ok: true,
      oauthScope: lastOAuthScope,
      ...(await getCopilotReport()),
    };

    console.log("[CopilotForge][Sidecar] /copilot/report", JSON.stringify(report));
    res.json(report);
  } catch (error) {
    res.status(500).json({ ok: false, error: String(error) });
  }
});

app.get("/models", async (_req, res) => {
  try {
    const models = await listAvailableModels();
    res.json({ ok: true, models });
  } catch (error) {
    res.status(500).json({ ok: false, error: String(error) });
  }
});

app.post("/auth/start", async (req, res) => {
  try {
    const result = await startDeviceFlow(req.body?.clientId);
    res.json({ ok: true, ...result });
  } catch (error) {
    res.status(400).json({ ok: false, error: String(error) });
  }
});

app.post("/auth/poll", async (req, res) => {
  try {
    const pollResult = await pollDeviceFlow(req.body?.clientId, req.body?.deviceCode);

    if (!pollResult.ok) {
      res.json({ ok: true, ...pollResult });
      return;
    }

    await startClient(pollResult.access_token);
    lastOAuthScope = pollResult.scope ?? (await fetchTokenScopes(pollResult.access_token));
    console.log("[CopilotForge][Sidecar] Copilot auth ready", JSON.stringify({
      authenticated: isAuthenticated(),
      scope: lastOAuthScope,
    }));

    res.json({
      ok: true,
      status: "authorized",
      access_token: pollResult.access_token,
      token_type: pollResult.token_type,
      scope: pollResult.scope,
    });
  } catch (error) {
    clearSession();
    res.status(500).json({ ok: false, error: String(error) });
  }
});

app.post("/auth", async (req, res) => {
  try {
    await startClient(req.body?.token);
    lastOAuthScope = await fetchTokenScopes(req.body?.token);
    res.json({ ok: true, authenticated: true });
  } catch (error) {
    clearSession();
    res.status(500).json({ ok: false, error: String(error) });
  }
});

registerPromptRoute(app);

const port = 7878;
const host = (process.env.COPILOTFORGE_SIDECAR_HOST ?? "0.0.0.0").trim() || "0.0.0.0";
const server = app.listen(port, host, () => {
  const urls = resolvedStartupURLs(host, port);
  console.log(`[CopilotForge] sidecar ready on ${host}:${port}`);
  for (const url of urls) {
    console.log(`[CopilotForge] health URL: ${url}/health`);
  }
});

server.on("error", (error: any) => {
  if (error?.code !== "EADDRINUSE") {
    console.error("[CopilotForge][Sidecar] startup failed", String(error));
    process.exit(1);
    return;
  }

  (async () => {
    const healthy = await isHealthySidecarAlreadyRunning(port);

    if (healthy) {
      console.log(`[CopilotForge][Sidecar] port :${port} already served by healthy sidecar; reusing existing instance`);
      process.exit(0);
      return;
    }

    console.error(`[CopilotForge][Sidecar] port :${port} is in use by another process`);
    process.exit(1);
  })();
});
