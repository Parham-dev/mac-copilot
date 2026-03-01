import { ProtocolMarkupFilter, protocolMarkerPattern } from "../promptStreaming/protocolMarkup.js";
import { extractToolExecutionResult } from "../promptStreaming/toolExecution.js";
import { extractIncrementalDelta, mergeDeltaText, normalizeUsagePayload, } from "./copilotPromptStreamingUtils.js";
const promptTraceEnabled = process.env.COPILOTFORGE_PROMPT_TRACE === "1";
export async function streamPromptWithSession(session, prompt, onEvent, debugLabel) {
    const trimmedPrompt = String(prompt ?? "").trim();
    if (!trimmedPrompt) {
        onEvent({ type: "text", text: "Please enter a prompt." });
        return;
    }
    let sawAnyOutput = false;
    let sawDeltaOutput = false;
    let sawToolCompletion = false;
    let resolveDone;
    let rejectDone;
    const done = new Promise((resolve, reject) => {
        resolveDone = resolve;
        rejectDone = reject;
    });
    const timeoutMs = 120000;
    const timeoutId = setTimeout(() => {
        rejectDone(new Error(`Copilot response timed out after ${timeoutMs}ms`));
    }, timeoutMs);
    const toolNameByCallID = new Map();
    const protocolFilter = new ProtocolMarkupFilter();
    let mergedDeltaText = "";
    const traceID = debugLabel?.trim().length ? debugLabel.trim() : `session-${Date.now().toString(36)}`;
    const logTrace = (message, extras) => {
        if (!promptTraceEnabled) {
            return;
        }
        if (extras) {
            console.log(`[CopilotForge][PromptTrace][${traceID}] ${message}`, JSON.stringify(extras));
            return;
        }
        console.log(`[CopilotForge][PromptTrace][${traceID}] ${message}`);
    };
    onEvent({ type: "status", label: "Analyzing request" });
    const unsubscribeTurnStart = session.on("assistant.turn_start", () => {
        onEvent({ type: "status", label: "Generating response" });
    });
    const unsubscribeDelta = session.on("assistant.message_delta", (event) => {
        const delta = event?.data?.deltaContent;
        if (typeof delta === "string" && delta.length > 0) {
            const nextMerged = mergeDeltaText(mergedDeltaText, delta);
            const incremental = extractIncrementalDelta(mergedDeltaText, nextMerged);
            mergedDeltaText = nextMerged;
            if (incremental.length === 0) {
                return;
            }
            sawDeltaOutput = true;
            const filtered = protocolFilter.process(incremental);
            if (promptTraceEnabled) {
                const rawHasProtocolMarkup = protocolMarkerPattern.test(delta);
                const filteredHasProtocolMarkup = protocolMarkerPattern.test(filtered);
                if (rawHasProtocolMarkup || filteredHasProtocolMarkup) {
                    logTrace("delta protocol marker observation", {
                        rawLength: delta.length,
                        incrementalLength: incremental.length,
                        filteredLength: filtered.length,
                        rawHasProtocolMarkup,
                        filteredHasProtocolMarkup,
                        rawPreview: delta.slice(0, 160),
                        incrementalPreview: incremental.slice(0, 160),
                        filteredPreview: filtered.slice(0, 160),
                    });
                }
            }
            if (filtered.length > 0) {
                sawAnyOutput = true;
                onEvent({ type: "text", text: filtered });
            }
        }
    });
    const unsubscribeFinal = session.on("assistant.message", (event) => {
        const content = event?.data?.content;
        if (!sawDeltaOutput && typeof content === "string" && content.length > 0) {
            const filtered = protocolFilter.process(content) + protocolFilter.flush();
            if (promptTraceEnabled) {
                const rawHasProtocolMarkup = protocolMarkerPattern.test(content);
                const filteredHasProtocolMarkup = protocolMarkerPattern.test(filtered);
                if (rawHasProtocolMarkup || filteredHasProtocolMarkup) {
                    logTrace("final message protocol marker observation", {
                        rawLength: content.length,
                        filteredLength: filtered.length,
                        rawHasProtocolMarkup,
                        filteredHasProtocolMarkup,
                        rawPreview: content.slice(0, 200),
                        filteredPreview: filtered.slice(0, 200),
                    });
                }
            }
            if (filtered.length > 0) {
                sawAnyOutput = true;
                onEvent({ type: "text", text: filtered });
            }
        }
    });
    const unsubscribeToolStart = session.on("tool.execution_start", (event) => {
        const toolCallID = event?.data?.toolCallId;
        const toolName = event?.data?.toolName ?? event?.data?.mcpToolName ?? "Tool";
        if (typeof toolCallID === "string" && toolCallID.length > 0) {
            toolNameByCallID.set(toolCallID, toolName);
        }
        onEvent({
            type: "tool_start",
            toolName,
            toolCallID,
        });
    });
    const unsubscribeToolComplete = session.on("tool.execution_complete", (event) => {
        const { toolName, success, details, toolCallID } = extractToolExecutionResult(event, toolNameByCallID);
        sawToolCompletion = true;
        sawAnyOutput = true;
        onEvent({
            type: "tool_complete",
            toolName,
            toolCallID,
            success,
            details,
        });
    });
    const unsubscribeUsage = session.on("assistant.usage", (event) => {
        const usage = normalizeUsagePayload(event?.data);
        if (!usage) {
            return;
        }
        onEvent({
            type: "usage",
            ...usage,
        });
        logTrace("assistant usage", usage);
    });
    const unsubscribeIdle = session.on("session.idle", () => {
        onEvent({ type: "done" });
        resolveDone();
    });
    try {
        await session.send({ prompt: trimmedPrompt, mode: "immediate" });
        await done;
        const remaining = protocolFilter.flush();
        if (promptTraceEnabled) {
            const remainingHasProtocolMarkup = protocolMarkerPattern.test(remaining);
            if (remainingHasProtocolMarkup) {
                logTrace("flush emitted protocol-like marker", {
                    remainingLength: remaining.length,
                    preview: remaining.slice(0, 200),
                });
            }
        }
        if (remaining.length > 0) {
            sawAnyOutput = true;
            onEvent({ type: "text", text: remaining });
        }
        if (!sawAnyOutput && !sawToolCompletion) {
            onEvent({ type: "text", text: "Copilot returned no text output for this request." });
        }
    }
    finally {
        logTrace("stream finished", { sawAnyOutput, sawDeltaOutput });
        clearTimeout(timeoutId);
        unsubscribeTurnStart();
        unsubscribeDelta();
        unsubscribeFinal();
        unsubscribeToolStart();
        unsubscribeToolComplete();
        unsubscribeUsage();
        unsubscribeIdle();
    }
}
