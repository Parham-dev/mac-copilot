const protocolTagNames = ["function_calls", "system_notification", "invoke", "parameter"];
const openingTagPattern = new RegExp(`<\\s*(${protocolTagNames.join("|")})\\b[^>]*>`, "i");
const protocolMarkerPattern = /<\s*\/?\s*(function_calls|system_notification|invoke|parameter)\b[^>]*>/i;
class ProtocolMarkupFilter {
    activeTag = null;
    tail = "";
    maxTailLength = 256;
    process(chunk) {
        let text = this.tail + chunk;
        this.tail = "";
        let output = "";
        while (text.length > 0) {
            if (this.activeTag) {
                const closeMatch = findClosingTag(text, this.activeTag);
                if (!closeMatch) {
                    const keepLength = Math.min(text.length, this.maxTailLength);
                    this.tail = text.slice(-keepLength);
                    return output;
                }
                text = text.slice(closeMatch.end);
                this.activeTag = null;
                continue;
            }
            const openMatch = findOpeningTag(text);
            if (!openMatch) {
                const safeLength = Math.max(0, text.length - this.maxTailLength);
                output += text.slice(0, safeLength);
                this.tail = text.slice(safeLength);
                return sanitizeInlineProtocolTags(output);
            }
            output += text.slice(0, openMatch.start);
            text = text.slice(openMatch.end);
            this.activeTag = openMatch.tagName;
        }
        return sanitizeInlineProtocolTags(output);
    }
    flush() {
        if (this.activeTag) {
            this.activeTag = null;
            this.tail = "";
            return "";
        }
        const remaining = sanitizeInlineProtocolTags(this.tail);
        this.tail = "";
        return remaining;
    }
}
function findOpeningTag(text) {
    const match = openingTagPattern.exec(text);
    if (!match || typeof match.index !== "number") {
        return null;
    }
    return {
        start: match.index,
        end: match.index + match[0].length,
        tagName: String(match[1]).toLowerCase(),
    };
}
function findClosingTag(text, tagName) {
    const escapedTagName = tagName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const pattern = new RegExp(`<\\s*\\/\\s*${escapedTagName}\\s*>`, "i");
    const match = pattern.exec(text);
    if (!match || typeof match.index !== "number") {
        return null;
    }
    return {
        start: match.index,
        end: match.index + match[0].length,
    };
}
function sanitizeInlineProtocolTags(text) {
    return protocolTagNames.reduce((acc, tagName) => {
        const escapedTagName = tagName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        return acc
            .replace(new RegExp(`<\\s*${escapedTagName}\\b[^>]*>`, "gi"), "")
            .replace(new RegExp(`<\\s*\\/\\s*${escapedTagName}\\s*>`, "gi"), "");
    }, text);
}
export async function streamPromptWithSession(session, prompt, onEvent, debugLabel) {
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
    const protocolFilter = new ProtocolMarkupFilter();
    const traceID = debugLabel?.trim().length ? debugLabel.trim() : `session-${Date.now().toString(36)}`;
    const logTrace = (message, extras) => {
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
            const rawHasProtocolMarkup = protocolMarkerPattern.test(delta);
            const filtered = protocolFilter.process(delta);
            const filteredHasProtocolMarkup = protocolMarkerPattern.test(filtered);
            if (rawHasProtocolMarkup || filteredHasProtocolMarkup) {
                logTrace("delta protocol marker observation", {
                    rawLength: delta.length,
                    filteredLength: filtered.length,
                    rawHasProtocolMarkup,
                    filteredHasProtocolMarkup,
                    rawPreview: delta.slice(0, 160),
                    filteredPreview: filtered.slice(0, 160),
                });
            }
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
            const filtered = protocolFilter.process(content) + protocolFilter.flush();
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
        const remaining = protocolFilter.flush();
        const remainingHasProtocolMarkup = protocolMarkerPattern.test(remaining);
        if (remainingHasProtocolMarkup) {
            logTrace("flush emitted protocol-like marker", {
                remainingLength: remaining.length,
                preview: remaining.slice(0, 200),
            });
        }
        if (remaining.length > 0) {
            sawAnyOutput = true;
            onEvent({ type: "text", text: remaining });
        }
        if (!sawAnyOutput) {
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
        unsubscribeIdle();
    }
}
