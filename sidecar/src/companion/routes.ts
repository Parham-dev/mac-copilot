import type { Express } from "express";
import { CompanionStore } from "./store.js";

const store = new CompanionStore();

function asErrorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

export function registerCompanionRoutes(app: Express) {
  app.get("/companion/status", (_req, res) => {
    res.json({ ok: true, ...store.status() });
  });

  app.post("/companion/pairing/start", (req, res) => {
    try {
      const ttlSeconds = Number(req.body?.ttlSeconds ?? 300);
      const payload = store.startPairing(Number.isFinite(ttlSeconds) ? ttlSeconds : 300);
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
