const functionCallsStartToken = "<function_calls>";
const functionCallsEndToken = "</function_calls>";
class FunctionCallMarkupFilter {
    inFunctionBlock = false;
    tail = "";
    process(chunk) {
        let text = this.tail + chunk;
        this.tail = "";
        let output = "";
        while (text.length > 0) {
            if (this.inFunctionBlock) {
                const endIndex = text.indexOf(functionCallsEndToken);
                if (endIndex < 0) {
                    const keepTailLength = Math.min(text.length, functionCallsEndToken.length - 1);
                    this.tail = text.slice(-keepTailLength);
                    return output;
                }
                text = text.slice(endIndex + functionCallsEndToken.length);
                this.inFunctionBlock = false;
                continue;
            }
            const startIndex = text.indexOf(functionCallsStartToken);
            if (startIndex < 0) {
                const safeLength = Math.max(0, text.length - (functionCallsStartToken.length - 1));
                output += text.slice(0, safeLength);
                this.tail = text.slice(safeLength);
                return output;
            }
            output += text.slice(0, startIndex);
            text = text.slice(startIndex + functionCallsStartToken.length);
            this.inFunctionBlock = true;
        }
        return output;
    }
    flush() {
        if (this.inFunctionBlock) {
            this.tail = "";
            return "";
        }
        const remaining = this.tail;
        this.tail = "";
        return remaining;
    }
}
function sanitizeToolMarkup(text) {
    return text
        .replace(/<\/?function_calls>/gi, "")
        .replace(/<invoke[^>]*>/gi, "")
        .replace(/<\/invoke>/gi, "")
        .replace(/<parameter[^>]*>/gi, "")
        .replace(/<\/parameter>/gi, "");
}
export async function streamPromptWithSession(session, prompt, onEvent) {
    const trimmedPrompt = String(prompt ?? "").trim();
    if (!trimmedPrompt) {
        onEvent({ type: "text", text: "Please enter a prompt." });
        return;
    }
    let sawAnyOutput = false;
    let sawDeltaOutput = false;
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
    const functionCallFilter = new FunctionCallMarkupFilter();
    onEvent({ type: "status", label: "Analyzing request" });
    const unsubscribeTurnStart = session.on("assistant.turn_start", () => {
        onEvent({ type: "status", label: "Generating response" });
    });
    const unsubscribeDelta = session.on("assistant.message_delta", (event) => {
        const delta = event?.data?.deltaContent;
        if (typeof delta === "string" && delta.length > 0) {
            const filtered = sanitizeToolMarkup(functionCallFilter.process(delta));
            if (filtered.length > 0) {
                sawAnyOutput = true;
                sawDeltaOutput = true;
                onEvent({ type: "text", text: filtered });
            }
        }
    });
    const unsubscribeFinal = session.on("assistant.message", (event) => {
        const content = event?.data?.content;
        if (!sawDeltaOutput && typeof content === "string" && content.length > 0) {
            const filtered = sanitizeToolMarkup(functionCallFilter.process(content) + functionCallFilter.flush());
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
        });
    });
    const unsubscribeToolComplete = session.on("tool.execution_complete", (event) => {
        const toolCallID = event?.data?.toolCallId;
        const toolName = event?.data?.toolName
            ?? (typeof toolCallID === "string" ? toolNameByCallID.get(toolCallID) : null)
            ?? "Tool";
        if (typeof toolCallID === "string" && toolCallID.length > 0) {
            toolNameByCallID.delete(toolCallID);
        }
        const resultContents = event?.data?.result?.contents;
        const firstContentText = Array.isArray(resultContents)
            ? resultContents
                .map((item) => {
                if (item?.type === "text" && typeof item.text === "string") {
                    return item.text;
                }
                if (item?.type === "terminal" && typeof item.text === "string") {
                    return item.text;
                }
                return null;
            })
                .find((value) => typeof value === "string" && value.trim().length > 0)
            : null;
        const resultContent = event?.data?.result?.content;
        const errorMessage = event?.data?.error?.message;
        const detailsRaw = (typeof firstContentText === "string" && firstContentText.length > 0 ? firstContentText : null)
            ?? (typeof resultContent === "string" && resultContent.length > 0 ? resultContent : null)
            ?? (typeof errorMessage === "string" && errorMessage.length > 0 ? errorMessage : null);
        let details = typeof detailsRaw === "string" ? detailsRaw : "";
        details = details
            .replace(/\n+/g, " ")
            .replace(/^\s*\d+\s*/, "")
            .replace(/<?exited?\s+with\s+exit\s*code\s*\d+>?/gi, "")
            .trim();
        if (!details && event?.data?.success !== false) {
            details = "Command completed successfully.";
        }
        onEvent({
            type: "tool_complete",
            toolName,
            success: event?.data?.success !== false,
            details: details.length > 0 ? details.slice(0, 280) : undefined,
        });
    });
    const unsubscribeIdle = session.on("session.idle", () => {
        onEvent({ type: "done" });
        resolveDone();
    });
    try {
        await session.send({ prompt: trimmedPrompt, mode: "immediate" });
        await done;
        const remaining = sanitizeToolMarkup(functionCallFilter.flush());
        if (remaining.length > 0) {
            sawAnyOutput = true;
            onEvent({ type: "text", text: remaining });
        }
        if (!sawAnyOutput) {
            onEvent({ type: "text", text: "Copilot returned no text output for this request." });
        }
    }
    finally {
        clearTimeout(timeoutId);
        unsubscribeTurnStart();
        unsubscribeDelta();
        unsubscribeFinal();
        unsubscribeToolStart();
        unsubscribeToolComplete();
        unsubscribeIdle();
    }
}
