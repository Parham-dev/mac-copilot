import express from "express";
import { sendPrompt, startClient, isAuthenticated, clearSession, getCopilotReport } from "./copilot.js";
import { pollDeviceFlow, startDeviceFlow, fetchTokenScopes } from "./auth.js";

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

app.post("/prompt", async (req, res) => {
  const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  const promptText = String(req.body?.prompt ?? "");

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  if (typeof res.flushHeaders === "function") {
    res.flushHeaders();
  }

  let chunkCount = 0;
  let totalChars = 0;

  console.log("[CopilotForge][Prompt] start", JSON.stringify({
    requestId,
    promptChars: promptText.length,
    authenticated: isAuthenticated(),
  }));

  try {
    await sendPrompt(promptText, (chunk) => {
      const text = typeof chunk === "string" ? chunk : JSON.stringify(chunk);
      chunkCount += 1;
      totalChars += text.length;
      res.write(`data: ${JSON.stringify({ text })}\n\n`);
    });

    console.log("[CopilotForge][Prompt] done", JSON.stringify({
      requestId,
      chunkCount,
      totalChars,
    }));

    res.write("data: [DONE]\n\n");
  } catch (error) {
    console.error("[CopilotForge][Prompt] error", JSON.stringify({
      requestId,
      error: String(error),
      chunkCount,
      totalChars,
    }));
    res.write(`data: ${JSON.stringify({ error: String(error) })}\n\n`);
  }

  res.end();
});

const port = 7878;
app.listen(port, () => {
  console.log(`[CopilotForge] sidecar ready on :${port}`);
});
