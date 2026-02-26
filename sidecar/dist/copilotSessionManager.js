import { approveAll } from "@github/copilot-sdk";
import { mkdirSync } from "node:fs";
export class CopilotSessionManager {
    sessionByChatKey = new Map();
    lastSessionState = null;
    reset() {
        this.sessionByChatKey.clear();
        this.lastSessionState = null;
    }
    hasActiveSessions() {
        return this.sessionByChatKey.size > 0;
    }
    sessionCount() {
        return this.sessionByChatKey.size;
    }
    activeSnapshot() {
        return {
            model: this.lastSessionState?.model ?? null,
            workingDirectory: this.lastSessionState?.workingDirectory ?? null,
            availableTools: this.lastSessionState?.availableTools ?? null,
        };
    }
    async ensureSessionForContext(client, args) {
        const requestedModel = typeof args.model === "string" ? args.model.trim() : "";
        if (!requestedModel) {
            throw new Error("No model selected. Load models and choose one before sending a prompt.");
        }
        const requestedWorkingDirectory = typeof args.projectPath === "string" && args.projectPath.trim().length > 0
            ? args.projectPath.trim()
            : null;
        const requestedAvailableTools = normalizeAllowedTools(args.allowedTools);
        const chatKey = normalizeChatKey(args.chatID, requestedWorkingDirectory ?? undefined);
        const existing = this.sessionByChatKey.get(chatKey);
        if (existing
            && existing.model === requestedModel
            && existing.workingDirectory === requestedWorkingDirectory
            && sameAllowedTools(existing.availableTools, requestedAvailableTools)) {
            this.lastSessionState = existing;
            return existing.session;
        }
        if (existing?.session && typeof existing.session.destroy === "function") {
            try {
                await existing.session.destroy();
            }
            catch {
            }
        }
        const state = await createOrResumeSessionForContext(client, {
            chatKey,
            model: requestedModel,
            workingDirectory: requestedWorkingDirectory,
            allowedTools: requestedAvailableTools,
        });
        this.sessionByChatKey.set(chatKey, state);
        this.lastSessionState = state;
        return state.session;
    }
}
function normalizeAllowedTools(allowedTools) {
    if (!Array.isArray(allowedTools)) {
        return null;
    }
    const normalized = Array.from(new Set(allowedTools
        .filter((entry) => typeof entry === "string")
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0))).sort((lhs, rhs) => lhs.localeCompare(rhs));
    return normalized.length > 0 ? normalized : null;
}
function sameAllowedTools(lhs, rhs) {
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
function normalizeChatKey(chatID, projectPath) {
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
function buildSessionIdentifier(chatKey) {
    const sanitized = chatKey
        .replace(/[^a-zA-Z0-9_-]/g, "-")
        .replace(/-+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 96);
    const suffix = sanitized.length > 0 ? sanitized : "default";
    return `copilotforge-${suffix}`;
}
async function createOrResumeSessionForContext(client, args) {
    if (!client) {
        throw new Error("Copilot client is not initialized.");
    }
    if (args.workingDirectory) {
        mkdirSync(args.workingDirectory, { recursive: true });
    }
    const sessionId = buildSessionIdentifier(args.chatKey);
    const config = {
        sessionId,
        model: args.model,
        streaming: true,
        onPermissionRequest: approveAll,
        infiniteSessions: {
            enabled: true,
        },
        ...(args.workingDirectory ? { workingDirectory: args.workingDirectory } : {}),
        ...(args.allowedTools ? { availableTools: args.allowedTools } : {}),
    };
    let createdSession;
    try {
        createdSession = await client.resumeSession(sessionId, config);
    }
    catch {
        createdSession = await client.createSession(config);
    }
    return {
        chatKey: args.chatKey,
        sessionId,
        session: createdSession,
        model: args.model,
        workingDirectory: args.workingDirectory,
        availableTools: args.allowedTools,
    };
}
