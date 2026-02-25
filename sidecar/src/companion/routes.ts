import type { Express, Request, Response } from "express";
import { isAuthenticated, sendPrompt } from "../copilot.js";
import { companionChatStore } from "./chatStore.js";
import { CompanionStore } from "./store.js";

const store = new CompanionStore();
const minimumPairingTTLSeconds = 60;
const maximumPairingTTLSeconds = 900;

function asErrorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

function normalizePairingTTL(input: unknown) {
  const value = Number(input ?? 300);
  if (!Number.isFinite(value)) {
    return 300;
  }

  return Math.max(minimumPairingTTLSeconds, Math.min(maximumPairingTTLSeconds, Math.trunc(value)));
}

function ensureCompanionAccess(res: Response) {
  const status = store.status();
  if (!status.connected) {
    res.status(403).json({ ok: false, error: "No paired companion device connected" });
    return false;
  }

  if (!isAuthenticated()) {
    res.status(401).json({ ok: false, error: "Copilot auth is required on Mac host" });
    return false;
  }

  return true;
}

function parseLimit(input: unknown) {
  const value = Number(input ?? 50);
  if (!Number.isFinite(value)) {
    return 50;
  }

  return Math.max(1, Math.min(200, Math.trunc(value)));
}

export function registerCompanionRoutes(app: Express) {
  app.get("/companion/status", (_req, res) => {
    res.json({ ok: true, ...store.status() });
  });

  app.post("/companion/pairing/start", (req, res) => {
    try {
      const ttlSeconds = normalizePairingTTL(req.body?.ttlSeconds);
      const payload = store.startPairing(ttlSeconds);
      res.json({ ok: true, ...payload });
    } catch (error) {
      res.status(400).json({ ok: false, error: asErrorMessage(error) });
    }
  });

  app.post("/companion/pairing/complete", (req, res) => {
    try {
      const payload = store.completePairing({
        pairingCode: req.body?.pairingCode,
        pairingToken: req.body?.pairingToken,
        deviceName: req.body?.deviceName,
        devicePublicKey: req.body?.devicePublicKey,
      });

      res.json({ ok: true, ...payload });
    } catch (error) {
      res.status(400).json({ ok: false, error: asErrorMessage(error) });
    }
  });

  app.post("/companion/disconnect", (_req, res) => {
    const payload = store.disconnect();
    res.json({ ok: true, ...payload });
  });

  app.post("/companion/sync/snapshot", (req, res) => {
    try {
      const imported = companionChatStore.importSnapshot(req.body ?? {});
      res.json({ ok: true, imported });
    } catch (error) {
      res.status(400).json({ ok: false, error: asErrorMessage(error) });
    }
  });

  app.get("/companion/projects", (_req, res) => {
    if (!ensureCompanionAccess(res)) {
      return;
    }

    res.json({ ok: true, projects: companionChatStore.listProjects() });
  });

  app.get("/companion/projects/:projectId/chats", (req, res) => {
    if (!ensureCompanionAccess(res)) {
      return;
    }

    res.json({ ok: true, chats: companionChatStore.listChats(String(req.params.projectId ?? "")) });
  });

  app.get("/companion/chats/:chatId/messages", (req, res) => {
    if (!ensureCompanionAccess(res)) {
      return;
    }

    const chatId = String(req.params.chatId ?? "").trim();
    if (!chatId) {
      res.status(400).json({ ok: false, error: "Missing chat id" });
      return;
    }

    const limit = parseLimit(req.query.limit);
    const cursor = typeof req.query.cursor === "string" ? req.query.cursor : undefined;
    const page = companionChatStore.listMessages(chatId, cursor, limit);
    res.json({ ok: true, chatId, ...page });
  });

  app.post("/companion/chats/:chatId/continue", async (req: Request, res: Response) => {
    if (!ensureCompanionAccess(res)) {
      return;
    }

    const chatId = String(req.params.chatId ?? "").trim();
    const prompt = String(req.body?.prompt ?? "").trim();
    const projectPath = typeof req.body?.projectPath === "string" ? req.body.projectPath : undefined;
    const model = typeof req.body?.model === "string" ? req.body.model : undefined;
    const allowedTools = Array.isArray(req.body?.allowedTools) ? req.body.allowedTools : undefined;

    if (!chatId) {
      res.status(400).json({ ok: false, error: "Missing chat id" });
      return;
    }

    if (!prompt) {
      res.status(400).json({ ok: false, error: "Prompt is required" });
      return;
    }

    companionChatStore.recordUserPrompt({ chatId, projectPath, prompt });

    const requestId = `companion-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
    let assistantText = "";

    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    if (typeof (res as any).flushHeaders === "function") {
      (res as any).flushHeaders();
    }

    try {
      await sendPrompt(prompt, chatId, model, projectPath, allowedTools, requestId, (event) => {
        const payload = typeof event === "object" && event !== null
          ? event
          : { type: "text", text: String(event ?? "") };

        if (payload.type === "text" && typeof payload.text === "string") {
          assistantText += payload.text;
        }

        res.write(`data: ${JSON.stringify(payload)}\n\n`);
      });

      companionChatStore.recordAssistantResponse(chatId, assistantText);
      res.write("data: [DONE]\n\n");
      res.end();
    } catch (error) {
      res.write(`data: ${JSON.stringify({ type: "error", error: asErrorMessage(error) })}\n\n`);
      res.end();
    }
  });

  app.get("/companion/devices", (_req, res) => {
    res.json({ ok: true, devices: store.listDevices() });
  });

  app.delete("/companion/devices/:id", (req, res) => {
    try {
      const payload = store.revokeDevice(req.params.id);
      res.json({ ok: true, ...payload });
    } catch (error) {
      res.status(400).json({ ok: false, error: asErrorMessage(error) });
    }
  });

  app.post("/companion/command", (_req, res) => {
    res.status(501).json({
      ok: false,
      error: "Signed command channel is not implemented yet",
    });
  });
}
