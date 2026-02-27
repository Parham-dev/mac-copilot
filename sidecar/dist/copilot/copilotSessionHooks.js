const DEFAULT_MAX_TOOL_ARGS_BYTES = 24_000;
const DEFAULT_MAX_TOOL_RESULT_BYTES = 20_000;
const DEFAULT_MAX_STRING_VALUE_BYTES = 8_000;
const DEFAULT_MAX_LOG_PREVIEW_BYTES = 1_000;
const REDACTION_PATTERNS = [
    /(gh[pousr]_[A-Za-z0-9_]{20,})/g,
    /(github_pat_[A-Za-z0-9_]{20,})/g,
    /(api[_-]?key\s*[:=]\s*["']?[^\s"']+["']?)/gi,
    /(token\s*[:=]\s*["']?[^\s"']+["']?)/gi,
    /(password\s*[:=]\s*["']?[^\s"']+["']?)/gi,
    /(secret\s*[:=]\s*["']?[^\s"']+["']?)/gi,
];
function readPositiveIntegerEnv(name, fallback) {
    const raw = process.env[name];
    if (!raw) {
        return fallback;
    }
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
function readBlockedTools() {
    const value = String(process.env.COPILOTFORGE_BLOCKED_TOOLS ?? "").trim();
    if (!value) {
        return new Set();
    }
    const blocked = value
        .split(",")
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0);
    return new Set(blocked);
}
function safeJSONStringify(value) {
    try {
        return JSON.stringify(value);
    }
    catch {
        return "[unserializable]";
    }
}
function redactString(input) {
    let current = input;
    for (const pattern of REDACTION_PATTERNS) {
        current = current.replace(pattern, "[REDACTED]");
    }
    return current;
}
function redactValue(value) {
    if (typeof value === "string") {
        return redactString(value);
    }
    if (Array.isArray(value)) {
        return value.map((entry) => redactValue(entry));
    }
    if (value && typeof value === "object") {
        const output = {};
        for (const [key, entry] of Object.entries(value)) {
            output[key] = redactValue(entry);
        }
        return output;
    }
    return value;
}
function truncateString(value, maxBytes) {
    if (value.length <= maxBytes) {
        return value;
    }
    return `${value.slice(0, maxBytes)}...[truncated ${value.length - maxBytes} chars]`;
}
function describeResultSize(value) {
    const serialized = safeJSONStringify(value);
    return {
        bytes: serialized.length,
        preview: truncateString(redactString(serialized), readPositiveIntegerEnv("COPILOTFORGE_MAX_LOG_PREVIEW_BYTES", DEFAULT_MAX_LOG_PREVIEW_BYTES)),
    };
}
export function buildSessionHooks(args) {
    const maxToolArgsBytes = readPositiveIntegerEnv("COPILOTFORGE_MAX_TOOL_ARGS_BYTES", DEFAULT_MAX_TOOL_ARGS_BYTES);
    const maxToolResultBytes = readPositiveIntegerEnv("COPILOTFORGE_MAX_TOOL_RESULT_BYTES", DEFAULT_MAX_TOOL_RESULT_BYTES);
    const maxStringValueBytes = readPositiveIntegerEnv("COPILOTFORGE_MAX_STRING_VALUE_BYTES", DEFAULT_MAX_STRING_VALUE_BYTES);
    const blockedTools = readBlockedTools();
    const allowedToolSet = args.allowedTools ? new Set(args.allowedTools) : null;
    return {
        onUserPromptSubmitted: async (input, invocation) => {
            const prompt = typeof input?.prompt === "string" ? input.prompt : "";
            console.log("[CopilotForge][Hooks] user_prompt_submitted", JSON.stringify({
                sessionId: invocation?.sessionId,
                chatKey: args.chatKey,
                promptLength: prompt.length,
                cwd: input?.cwd,
            }));
            return null;
        },
        onSessionStart: async (input, invocation) => {
            console.log("[CopilotForge][Hooks] session_start", JSON.stringify({
                sessionId: invocation?.sessionId,
                chatKey: args.chatKey,
                source: input?.source,
                cwd: input?.cwd,
                workingDirectory: args.workingDirectory,
            }));
            return null;
        },
        onSessionEnd: async (input, invocation) => {
            console.log("[CopilotForge][Hooks] session_end", JSON.stringify({
                sessionId: invocation?.sessionId,
                chatKey: args.chatKey,
                reason: input?.reason,
                hasError: typeof input?.error === "string" && input.error.length > 0,
            }));
            return null;
        },
        onPreToolUse: async (input, invocation) => {
            const toolName = typeof input?.toolName === "string" ? input.toolName : "";
            const toolArgs = input?.toolArgs;
            const serializedArgs = safeJSONStringify(toolArgs);
            if (!toolName) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason: "Tool call denied: missing tool name.",
                };
            }
            if (blockedTools.has(toolName)) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason: `Tool '${toolName}' is blocked by sidecar policy.`,
                };
            }
            if (allowedToolSet && !allowedToolSet.has(toolName)) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason: `Tool '${toolName}' is not in the allowed tool list for this chat context.`,
                };
            }
            if (serializedArgs.length > maxToolArgsBytes) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason: `Tool '${toolName}' arguments exceed the configured size limit (${maxToolArgsBytes} bytes).`,
                };
            }
            if (typeof toolArgs?.command === "string" && toolArgs.command.length > maxStringValueBytes) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason: `Tool '${toolName}' command exceeds the configured size limit (${maxStringValueBytes} chars).`,
                };
            }
            console.log("[CopilotForge][Hooks] pre_tool_use", JSON.stringify({
                sessionId: invocation?.sessionId,
                chatKey: args.chatKey,
                toolName,
                argsBytes: serializedArgs.length,
            }));
            return {
                permissionDecision: "allow",
            };
        },
        onPostToolUse: async (input, invocation) => {
            const toolName = typeof input?.toolName === "string" ? input.toolName : "unknown";
            const rawResult = input?.toolResult;
            const redactedResult = redactValue(rawResult);
            const size = describeResultSize(redactedResult);
            console.log("[CopilotForge][Hooks] post_tool_use", JSON.stringify({
                sessionId: invocation?.sessionId,
                chatKey: args.chatKey,
                toolName,
                resultBytes: size.bytes,
                resultPreview: size.preview,
            }));
            if (size.bytes <= maxToolResultBytes) {
                if (safeJSONStringify(rawResult) !== safeJSONStringify(redactedResult)) {
                    return { modifiedResult: redactedResult };
                }
                return null;
            }
            const compact = {
                truncated: true,
                originalBytes: size.bytes,
                maxBytes: maxToolResultBytes,
                preview: truncateString(size.preview, maxToolResultBytes),
            };
            return {
                modifiedResult: compact,
                additionalContext: `Tool result was truncated from ${size.bytes} bytes to enforce output size limits.`,
            };
        },
        onErrorOccurred: async (input, invocation) => {
            console.error("[CopilotForge][Hooks] error_occurred", JSON.stringify({
                sessionId: invocation?.sessionId,
                chatKey: args.chatKey,
                context: input?.errorContext,
                recoverable: input?.recoverable,
                error: redactString(String(input?.error ?? "unknown error")),
            }));
            return null;
        },
    };
}
