import { existsSync } from "node:fs";
import { resolve } from "node:path";
const DEFAULT_FETCH_MCP_COMMAND = "uvx";
const DEFAULT_FETCH_MCP_ARGS = ["mcp-server-fetch"];
const DEFAULT_FETCH_MCP_TIMEOUT_MS = 30000;
export function normalizeAllowedTools(allowedTools) {
    if (!Array.isArray(allowedTools)) {
        return null;
    }
    const normalized = Array.from(new Set(allowedTools
        .filter((entry) => typeof entry === "string")
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0))).sort((lhs, rhs) => lhs.localeCompare(rhs));
    return normalized.length > 0 ? normalized : null;
}
function isLikelyMCPToolName(toolName) {
    return toolName === "fetch" || toolName.startsWith("fetch_");
}
export function selectAllowedTools(allowedTools) {
    const requestedAllowedTools = normalizeAllowedTools(allowedTools);
    if (!requestedAllowedTools) {
        return {
            requestedAllowedTools: null,
            nativeAvailableTools: null,
        };
    }
    const nativeAvailableTools = requestedAllowedTools.filter((toolName) => !isLikelyMCPToolName(toolName));
    return {
        requestedAllowedTools,
        nativeAvailableTools: nativeAvailableTools.length > 0 ? nativeAvailableTools : null,
    };
}
export function normalizeStringListEnv(name) {
    const raw = String(process.env[name] ?? "").trim();
    if (!raw) {
        return null;
    }
    const normalized = Array.from(new Set(raw
        .split(",")
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0))).sort((lhs, rhs) => lhs.localeCompare(rhs));
    return normalized.length > 0 ? normalized : null;
}
export function discoverDefaultSkillDirectories() {
    const candidates = [
        resolve(process.cwd(), "skills"),
        resolve(process.cwd(), "..", "skills"),
        resolve(process.cwd(), "..", "..", "skills"),
    ];
    const discovered = Array.from(new Set(candidates.filter((candidate) => existsSync(candidate)))).sort((lhs, rhs) => lhs.localeCompare(rhs));
    return discovered.length > 0 ? discovered : null;
}
export function sameAllowedTools(lhs, rhs) {
    if (lhs === null && rhs === null) {
        return true;
    }
    if (!Array.isArray(lhs) || !Array.isArray(rhs)) {
        return false;
    }
    if (lhs.length !== rhs.length) {
        return false;
    }
    return lhs.every((value, index) => value === rhs[index]);
}
export function sameStringList(lhs, rhs) {
    if (lhs === null && rhs === null) {
        return true;
    }
    if (!Array.isArray(lhs) || !Array.isArray(rhs)) {
        return false;
    }
    if (lhs.length !== rhs.length) {
        return false;
    }
    return lhs.every((value, index) => value === rhs[index]);
}
export function normalizeChatKey(chatID, projectPath) {
    const normalizedID = typeof chatID === "string" ? chatID.trim() : "";
    if (normalizedID.length > 0) {
        return normalizedID;
    }
    const normalizedPath = typeof projectPath === "string" ? projectPath.trim() : "";
    if (normalizedPath.length > 0) {
        return `project:${normalizedPath}`;
    }
    return "default";
}
export function buildSessionIdentifier(chatKey) {
    const sanitized = chatKey
        .replace(/[^a-zA-Z0-9_-]/g, "-")
        .replace(/-+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 96);
    const suffix = sanitized.length > 0 ? sanitized : "default";
    return `copilotforge-${suffix}`;
}
function readPositiveIntegerEnv(name, fallback) {
    const raw = String(process.env[name] ?? "").trim();
    if (!raw) {
        return fallback;
    }
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
function shouldEnableFetchMCP() {
    const raw = String(process.env.COPILOTFORGE_ENABLE_FETCH_MCP ?? "1").trim().toLowerCase();
    return raw !== "0" && raw !== "false" && raw !== "off";
}
function parseFetchMCPArgs() {
    const raw = String(process.env.COPILOTFORGE_FETCH_MCP_ARGS ?? "").trim();
    if (!raw) {
        return DEFAULT_FETCH_MCP_ARGS;
    }
    const parsed = raw
        .split(/\s+/)
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0);
    return parsed.length > 0 ? parsed : DEFAULT_FETCH_MCP_ARGS;
}
export function buildConfiguredMCPServers() {
    if (!shouldEnableFetchMCP()) {
        return undefined;
    }
    const fetchCommand = String(process.env.COPILOTFORGE_FETCH_MCP_COMMAND ?? "").trim() || DEFAULT_FETCH_MCP_COMMAND;
    const fetchArgs = parseFetchMCPArgs();
    const fetchTimeout = readPositiveIntegerEnv("COPILOTFORGE_FETCH_MCP_TIMEOUT_MS", DEFAULT_FETCH_MCP_TIMEOUT_MS);
    console.log("[CopilotForge][Session] Fetch MCP local mode", JSON.stringify({
        command: fetchCommand,
        args: fetchArgs,
        timeout: fetchTimeout,
    }));
    return {
        fetch: {
            type: "local",
            command: fetchCommand,
            args: fetchArgs,
            tools: ["*"],
            timeout: fetchTimeout,
        },
    };
}
