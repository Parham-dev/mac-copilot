export const DEFAULT_MAX_TOOL_ARGS_BYTES = 24_000;
export const DEFAULT_MAX_TOOL_RESULT_BYTES = 20_000;
export const DEFAULT_MAX_STRING_VALUE_BYTES = 8_000;
export const DEFAULT_MAX_LOG_PREVIEW_BYTES = 1_000;
const REDACTION_PATTERNS = [
    /(gh[pousr]_[A-Za-z0-9_]{20,})/g,
    /(github_pat_[A-Za-z0-9_]{20,})/g,
    /(api[_-]?key\s*[:=]\s*["']?[^\s"']+["']?)/gi,
    /(token\s*[:=]\s*["']?[^\s"']+["']?)/gi,
    /(password\s*[:=]\s*["']?[^\s"']+["']?)/gi,
    /(secret\s*[:=]\s*["']?[^\s"']+["']?)/gi,
];
export function readPositiveIntegerEnv(name, fallback) {
    const raw = process.env[name];
    if (!raw) {
        return fallback;
    }
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
export function readBlockedTools() {
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
export function normalizeToolName(value) {
    return value
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "_")
        .replace(/^_+|_+$/g, "");
}
export function isNativeWebFetchTool(toolName) {
    const normalized = normalizeToolName(toolName);
    return normalized === "web_fetch" || normalized === "fetch_webpage";
}
export function isAllowedToolName(toolName, allowedTools, normalizedAllowedTools) {
    if (allowedTools.has(toolName)) {
        return true;
    }
    const normalizedName = normalizeToolName(toolName);
    if (!normalizedName) {
        return false;
    }
    if (normalizedAllowedTools.has(normalizedName)) {
        return true;
    }
    const candidates = new Set([normalizedName]);
    const segments = normalizedName.split("_").filter((segment) => segment.length > 0);
    if (segments.length > 1) {
        candidates.add(segments.slice(1).join("_"));
    }
    const lastSegment = segments[segments.length - 1];
    if (lastSegment) {
        candidates.add(lastSegment);
    }
    for (const candidate of candidates) {
        if (normalizedAllowedTools.has(candidate)) {
            return true;
        }
    }
    return false;
}
export function safeJSONStringify(value) {
    try {
        return JSON.stringify(value);
    }
    catch {
        return "[unserializable]";
    }
}
export function redactString(input) {
    let current = input;
    for (const pattern of REDACTION_PATTERNS) {
        current = current.replace(pattern, "[REDACTED]");
    }
    return current;
}
export function redactValue(value) {
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
export function truncateString(value, maxBytes) {
    if (value.length <= maxBytes) {
        return value;
    }
    return `${value.slice(0, maxBytes)}...[truncated ${value.length - maxBytes} chars]`;
}
export function describeResultSize(value) {
    const serialized = safeJSONStringify(value);
    return {
        bytes: serialized.length,
        preview: truncateString(redactString(serialized), readPositiveIntegerEnv("COPILOTFORGE_MAX_LOG_PREVIEW_BYTES", DEFAULT_MAX_LOG_PREVIEW_BYTES)),
    };
}
