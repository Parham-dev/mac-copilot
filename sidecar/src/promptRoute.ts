import type { Express } from "express";
import { sendPrompt, isAuthenticated } from "./copilot/copilot.js";
import { companionChatStore } from "./companion/chatStore.js";
import { startPromptTelemetry } from "./telemetry/otel.js";

const protocolMarkerPattern = /<\s*\/?\s*(function_calls|system_notification|invoke|parameter)\b[^>]*>/i;
const promptTraceEnabled = process.env.COPILOTFORGE_PROMPT_TRACE === "1";

export function registerPromptRoute(app: Express) {
  app.post("/prompt", async (req, res) => {
    const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
    const promptText = String(req.body?.prompt ?? "");
    const chatID = typeof req.body?.chatID === "string" ? req.body.chatID : undefined;
    const projectPath = typeof req.body?.projectPath === "string" ? req.body.projectPath : undefined;

    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    if (typeof (res as any).flushHeaders === "function") {
      (res as any).flushHeaders();
    }

    let chunkCount = 0;
    let totalChars = 0;
    let assistantText = "";
    let usageEventCount = 0;
    let lastUsageSnapshot: Record<string, unknown> | null = null;

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

    const telemetry = await startPromptTelemetry({
      requestId,
      model: typeof req.body?.model === "string" ? req.body.model : undefined,
      chatId: chatID,
    });

    try {
      await sendPrompt(promptText, chatID, req.body?.model, projectPath, req.body?.allowedTools, requestId, (event) => {
        const payload = typeof event === "object" && event !== null
          ? event
          : { type: "text", text: String(event ?? "") };

        const maybeText = typeof (payload as any)?.text === "string" ? String((payload as any).text) : "";
        if (promptTraceEnabled && maybeText.length > 0 && protocolMarkerPattern.test(maybeText)) {
          console.warn("[CopilotForge][PromptTrace] outbound SSE payload contains protocol marker", JSON.stringify({
            requestId,
            textLength: maybeText.length,
            preview: maybeText.slice(0, 180),
          }));
        }

        const text = JSON.stringify(payload);
        if (payload.type === "usage") {
          usageEventCount += 1;
          lastUsageSnapshot = payload;
          telemetry.onUsage(payload);
        }
        if (payload.type === "tool_start" && typeof payload.toolName === "string") {
          telemetry.onToolStart(
            payload.toolName,
            typeof payload.toolCallID === "string" ? payload.toolCallID : undefined
          );
        }
        if (payload.type === "tool_complete" && typeof payload.toolName === "string") {
          telemetry.onToolComplete(
            payload.toolName,
            payload.success !== false,
            typeof payload.details === "string" ? payload.details : undefined,
            typeof payload.toolCallID === "string" ? payload.toolCallID : undefined
          );
        }
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
        usageEventCount,
        usage: lastUsageSnapshot,
      }));

      telemetry.end();

      res.write("data: [DONE]\n\n");
    } catch (error) {
      telemetry.fail(error);
      telemetry.end();
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
}
