import { sendPrompt, isAuthenticated } from "./copilot/copilot.js";
import { classifyToolName, summarizeToolPath } from "./copilot/agentToolPolicyRegistry.js";
import { companionChatStore } from "./companion/chatStore.js";
import { startPromptTelemetry } from "./telemetry/otel.js";
const protocolMarkerPattern = /<\s*\/?\s*(function_calls|system_notification|invoke|parameter|function|function_)\b[^>]*>/i;
const promptTraceEnabled = process.env.COPILOTFORGE_PROMPT_TRACE === "1";
export function registerPromptRoute(app) {
    app.post("/prompt", async (req, res) => {
        const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
        const promptText = String(req.body?.prompt ?? "");
        const chatID = typeof req.body?.chatID === "string" ? req.body.chatID : undefined;
        const projectPath = typeof req.body?.projectPath === "string" ? req.body.projectPath : undefined;
        const allowedTools = Array.isArray(req.body?.allowedTools)
            ? req.body.allowedTools.filter((entry) => typeof entry === "string")
            : null;
        const rawExecutionContext = req.body?.executionContext;
        const executionContext = rawExecutionContext && typeof rawExecutionContext === "object"
            ? {
                agentID: typeof rawExecutionContext.agentID === "string"
                    ? rawExecutionContext.agentID
                    : "",
                feature: typeof rawExecutionContext.feature === "string"
                    ? rawExecutionContext.feature
                    : "",
                policyProfile: typeof rawExecutionContext.policyProfile === "string"
                    ? rawExecutionContext.policyProfile
                    : "",
                skillNames: Array.isArray(rawExecutionContext.skillNames)
                    ? rawExecutionContext.skillNames
                        .filter((entry) => typeof entry === "string")
                    : [],
                requireSkills: rawExecutionContext.requireSkills === true,
                requestedOutputMode: typeof rawExecutionContext.requestedOutputMode === "string"
                    ? rawExecutionContext.requestedOutputMode
                    : "",
                requiredContract: typeof rawExecutionContext.requiredContract === "string"
                    ? rawExecutionContext.requiredContract
                    : "",
            }
            : null;
        const normalizedExecutionContext = executionContext
            && executionContext.agentID.trim().length > 0
            && executionContext.feature.trim().length > 0
            && executionContext.policyProfile.trim().length > 0
            ? {
                agentID: executionContext.agentID.trim(),
                feature: executionContext.feature.trim(),
                policyProfile: executionContext.policyProfile.trim(),
                skillNames: executionContext.skillNames
                    .map((entry) => entry.trim())
                    .filter((entry) => entry.length > 0),
                requireSkills: executionContext.requireSkills,
                requestedOutputMode: executionContext.requestedOutputMode.trim(),
                requiredContract: executionContext.requiredContract.trim(),
            }
            : null;
        res.setHeader("Content-Type", "text/event-stream");
        res.setHeader("Cache-Control", "no-cache");
        res.setHeader("Connection", "keep-alive");
        if (typeof res.flushHeaders === "function") {
            res.flushHeaders();
        }
        let chunkCount = 0;
        let totalChars = 0;
        let assistantText = "";
        let usageEventCount = 0;
        let lastUsageSnapshot = null;
        let toolStartCount = 0;
        let toolCompleteCount = 0;
        const toolNamesUsed = new Set();
        const toolClassesUsed = new Set();
        companionChatStore.recordUserPrompt({
            chatId: chatID,
            projectPath,
            prompt: promptText,
        });
        console.log("[CopilotForge][Prompt] start", JSON.stringify({
            requestId,
            promptChars: promptText.length,
            authenticated: isAuthenticated(),
            allowedToolsCount: allowedTools?.length ?? null,
            allowedToolsSample: allowedTools?.slice(0, 8) ?? null,
            executionContext: normalizedExecutionContext,
        }));
        const telemetry = await startPromptTelemetry({
            requestId,
            model: typeof req.body?.model === "string" ? req.body.model : undefined,
            chatId: chatID,
        });
        try {
            await sendPrompt(promptText, chatID, req.body?.model, projectPath, allowedTools, normalizedExecutionContext, requestId, (event) => {
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
                if (payload.type === "usage") {
                    usageEventCount += 1;
                    lastUsageSnapshot = payload;
                    telemetry.onUsage(payload);
                }
                if (payload.type === "tool_start" && typeof payload.toolName === "string") {
                    toolStartCount += 1;
                    toolNamesUsed.add(payload.toolName);
                    toolClassesUsed.add(classifyToolName(payload.toolName));
                    telemetry.onToolStart(payload.toolName, typeof payload.toolCallID === "string" ? payload.toolCallID : undefined);
                }
                if (payload.type === "tool_complete" && typeof payload.toolName === "string") {
                    toolCompleteCount += 1;
                    toolNamesUsed.add(payload.toolName);
                    toolClassesUsed.add(classifyToolName(payload.toolName));
                    telemetry.onToolComplete(payload.toolName, payload.success !== false, typeof payload.details === "string" ? payload.details : undefined, typeof payload.toolCallID === "string" ? payload.toolCallID : undefined);
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
                toolStartCount,
                toolCompleteCount,
                toolNamesUsed: Array.from(toolNamesUsed),
                tool_path: summarizeToolPath(toolClassesUsed).toolPath,
                fallback_used: summarizeToolPath(toolClassesUsed).fallbackUsed,
                usage: lastUsageSnapshot,
            }));
            telemetry.end();
            res.write("data: [DONE]\n\n");
        }
        catch (error) {
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
