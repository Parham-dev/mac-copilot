import express from "express";
import { sendPrompt, startClient, isAuthenticated, clearSession, getCopilotReport } from "./copilot.js";
import { pollDeviceFlow, startDeviceFlow } from "./auth.js";

const app = express();
app.use(express.json());

let lastOAuthScope = null;

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "copilotforge-sidecar" });
});

app.get("/auth/status", (_req, res) => {
  res.json({ ok: true, authenticated: isAuthenticated() });
});

app.get("/copilot/report", (_req, res) => {
  const report = {
    ok: true,
    oauthScope: lastOAuthScope,
    ...getCopilotReport(),
  };

  console.log("[CopilotForge][Sidecar] /copilot/report", JSON.stringify(report));
  res.json(report);
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
    lastOAuthScope = pollResult.scope ?? null;
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
    res.json({ ok: true, authenticated: true });
  } catch (error) {
    clearSession();
    res.status(500).json({ ok: false, error: String(error) });
  }
});

app.post("/prompt", async (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  try {
    await sendPrompt(req.body?.prompt ?? "", (chunk) => {
      res.write(`data: ${JSON.stringify({ text: chunk })}\n\n`);
    });
    res.write("data: [DONE]\\n\\n");
  } catch (error) {
    res.write(`data: ${JSON.stringify({ error: String(error) })}\\n\\n`);
  }

  res.end();
});

const port = 7878;
app.listen(port, () => {
  console.log(`[CopilotForge] sidecar ready on :${port}`);
});
