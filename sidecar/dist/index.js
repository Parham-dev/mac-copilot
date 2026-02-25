import express from "express";
import { existsSync } from "node:fs";
import { networkInterfaces } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { sendPrompt, startClient, isAuthenticated, clearSession, getCopilotReport, listAvailableModels } from "./copilot.js";
import { pollDeviceFlow, startDeviceFlow, fetchTokenScopes } from "./auth.js";
import { companionChatStore } from "./companion/chatStore.js";
import { registerCompanionRoutes } from "./companion/routes.js";
const app = express();
app.use(express.json());
registerCompanionRoutes(app);
const protocolMarkerPattern = /<\s*\/?\s*(function_calls|system_notification|invoke|parameter)\b[^>]*>/i;
const promptTraceEnabled = process.env.COPILOTFORGE_PROMPT_TRACE === "1";
const processStartedAtMs = Date.now();
let lastOAuthScope = null;
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
app.get("/copilot/report", (_req, res) => {
    const report = {
        ok: true,
        oauthScope: lastOAuthScope,
        ...getCopilotReport(),
    };
    console.log("[CopilotForge][Sidecar] /copilot/report", JSON.stringify(report));
    res.json(report);
});
app.get("/models", async (_req, res) => {
    try {
        const models = await listAvailableModels();
        res.json({ ok: true, models });
    }
    catch (error) {
        res.status(500).json({ ok: false, error: String(error), models: ["gpt-5"] });
    }
});
app.post("/auth/start", async (req, res) => {
    try {
        const result = await startDeviceFlow(req.body?.clientId);
        res.json({ ok: true, ...result });
    }
    catch (error) {
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
    }
    catch (error) {
        clearSession();
        res.status(500).json({ ok: false, error: String(error) });
    }
});
app.post("/auth", async (req, res) => {
    try {
        await startClient(req.body?.token);
        lastOAuthScope = await fetchTokenScopes(req.body?.token);
        res.json({ ok: true, authenticated: true });
    }
    catch (error) {
        clearSession();
        res.status(500).json({ ok: false, error: String(error) });
    }
});
app.post("/prompt", async (req, res) => {
    const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
    const promptText = String(req.body?.prompt ?? "");
    const chatID = typeof req.body?.chatID === "string" ? req.body.chatID : undefined;
    const projectPath = typeof req.body?.projectPath === "string" ? req.body.projectPath : undefined;
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    if (typeof res.flushHeaders === "function") {
        res.flushHeaders();
    }
    let chunkCount = 0;
    let totalChars = 0;
    let assistantText = "";
    companionChatStore.recordUserPrompt({
        chatId: chatID,
        projectPath,
        prompt: promptText,
    });
    console.log("[CopilotForge][Prompt] start", JSON.stringify({
        requestId,
        promptChars: promptText.length,
        authenticated: isAuthenticated(),
    }));
    try {
        await sendPrompt(promptText, chatID, req.body?.model, projectPath, req.body?.allowedTools, requestId, (event) => {
            const payload = typeof event === "object" && event !== null
                ? event
                : { type: "text", text: String(event ?? "") };
            const maybeText = typeof payload?.text === "string" ? String(payload.text) : "";
            if (promptTraceEnabled && maybeText.length > 0 && protocolMarkerPattern.test(maybeText)) {
                console.warn("[CopilotForge][PromptTrace] outbound SSE payload contains protocol marker", JSON.stringify({
                    requestId,
                    textLength: maybeText.length,
                    preview: maybeText.slice(0, 180),
                }));
            }
            const text = JSON.stringify(payload);
            if (payload.type === "text" && typeof payload.text === "string") {
                assistantText += payload.text;
            }
            chunkCount += 1;
            totalChars += text.length;
            res.write(`data: ${text}\n\n`);
        });
        if (chatID && assistantText.trim().length > 0) {
            companionChatStore.recordAssistantResponse(chatID, assistantText);
        }
        console.log("[CopilotForge][Prompt] done", JSON.stringify({
            requestId,
            chunkCount,
            totalChars,
        }));
        res.write("data: [DONE]\n\n");
    }
    catch (error) {
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
const host = (process.env.COPILOTFORGE_SIDECAR_HOST ?? "0.0.0.0").trim() || "0.0.0.0";
const server = app.listen(port, host, () => {
    const urls = resolvedStartupURLs(host, port);
    console.log(`[CopilotForge] sidecar ready on ${host}:${port}`);
    for (const url of urls) {
        console.log(`[CopilotForge] health URL: ${url}/health`);
    }
});
server.on("error", (error) => {
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
async function isHealthySidecarAlreadyRunning(portNumber) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 800);
    try {
        const response = await fetch(`http://127.0.0.1:${portNumber}/health`, {
            method: "GET",
            signal: controller.signal,
            headers: {
                "Cache-Control": "no-cache",
            },
        });
        if (!response.ok) {
            return false;
        }
        const body = await response.text();
        return body.includes("copilotforge-sidecar");
    }
    catch {
        return false;
    }
    finally {
        clearTimeout(timeout);
    }
}
async function buildDoctorReport() {
    const sqliteSupport = await supportsNodeSqlite();
    const sdkPath = resolveSDKPath();
    const sdkPresent = existsSync(sdkPath);
    return {
        ok: sqliteSupport && sdkPresent,
        service: "copilotforge-sidecar",
        nodeVersion: process.version,
        nodeExecPath: process.execPath,
        sqliteSupport,
        sdkPath,
        sdkPresent,
    };
}
async function supportsNodeSqlite() {
    try {
        await import("node:sqlite");
        return true;
    }
    catch {
        return false;
    }
}
function resolveSDKPath() {
    const currentFile = fileURLToPath(import.meta.url);
    const currentDir = dirname(currentFile);
    const candidates = [
        join(currentDir, "node_modules", "@github", "copilot-sdk"),
        join(currentDir, "..", "node_modules", "@github", "copilot-sdk"),
    ];
    for (const candidate of candidates) {
        if (existsSync(candidate)) {
            return candidate;
        }
    }
    return candidates[0];
}
function resolvedStartupURLs(hostValue, portValue) {
    const normalizedHost = hostValue.trim().toLowerCase();
    if (normalizedHost !== "0.0.0.0" && normalizedHost !== "::") {
        return [`http://${hostValue}:${portValue}`];
    }
    const urls = new Set();
    urls.add(`http://127.0.0.1:${portValue}`);
    urls.add(`http://localhost:${portValue}`);
    const interfaces = networkInterfaces();
    for (const candidates of Object.values(interfaces)) {
        if (!candidates) {
            continue;
        }
        for (const candidate of candidates) {
            if (!candidate || candidate.internal) {
                continue;
            }
            if (candidate.family === "IPv4") {
                urls.add(`http://${candidate.address}:${portValue}`);
            }
        }
    }
    return Array.from(urls).sort((left, right) => left.localeCompare(right));
}
