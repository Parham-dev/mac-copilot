import express from "express";
import { sendPrompt, startClient } from "./copilot.js";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "copilotforge-sidecar" });
});

app.post("/auth", async (req, res) => {
  try {
    await startClient(req.body?.token);
    res.json({ ok: true });
  } catch (error) {
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
