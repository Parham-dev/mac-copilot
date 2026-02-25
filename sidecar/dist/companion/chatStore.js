import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const defaultState = {
    projects: [],
    chats: [],
    messagesByChat: {},
};
export class CompanionChatStore {
    projects = new Map();
    chats = new Map();
    messagesByChat = new Map();
    constructor() {
        const state = loadState();
        for (const project of state.projects)
            this.projects.set(project.id, project);
        for (const chat of state.chats)
            this.chats.set(chat.id, chat);
        for (const [chatId, messages] of Object.entries(state.messagesByChat)) {
            this.messagesByChat.set(chatId, messages);
        }
    }
    recordUserPrompt(input) {
        const chatId = normalizeChatId(input.chatId, input.projectPath);
        const project = this.ensureProject(input.projectPath);
        this.ensureChat(chatId, project.id, input.prompt);
        this.pushMessage(chatId, "user", input.prompt);
        this.persist();
        return chatId;
    }
    recordAssistantResponse(chatId, text) {
        if (!text.trim())
            return;
        this.ensureChat(chatId, this.ensureProject(undefined).id, text);
        this.pushMessage(chatId, "assistant", text);
        this.persist();
    }
    listProjects() {
        return Array.from(this.projects.values()).sort((a, b) => b.lastUpdatedAt.localeCompare(a.lastUpdatedAt));
    }
    listChats(projectId) {
        return Array.from(this.chats.values())
            .filter((chat) => chat.projectId === projectId)
            .sort((a, b) => b.lastUpdatedAt.localeCompare(a.lastUpdatedAt));
    }
    listMessages(chatId, cursor, limit = 50) {
        const messages = this.messagesByChat.get(chatId) ?? [];
        const clampedLimit = Math.max(1, Math.min(limit, 200));
        const start = Number.isFinite(Number(cursor)) ? Math.max(0, Number(cursor)) : 0;
        const slice = messages.slice(start, start + clampedLimit);
        const nextCursor = start + clampedLimit < messages.length ? String(start + clampedLimit) : null;
        return { messages: slice, nextCursor };
    }
    chatById(chatId) {
        return this.chats.get(chatId) ?? null;
    }
    importSnapshot(snapshot) {
        const projects = Array.isArray(snapshot.projects) ? snapshot.projects : [];
        const chats = Array.isArray(snapshot.chats) ? snapshot.chats : [];
        const messages = Array.isArray(snapshot.messages) ? snapshot.messages : [];
        for (const project of projects) {
            if (!project.id || !project.name)
                continue;
            this.upsertProject(project);
        }
        for (const chat of chats) {
            if (!chat.id || !chat.projectId)
                continue;
            this.upsertChat(chat);
        }
        let importedMessages = 0;
        for (const message of messages) {
            if (!message.chatId || !message.id)
                continue;
            this.upsertMessage(message.chatId, {
                id: message.id,
                role: message.role === "assistant" ? "assistant" : "user",
                text: String(message.text ?? ""),
                createdAt: normalizeTimestamp(message.createdAt),
            });
            importedMessages += 1;
        }
        this.persist();
        return {
            projects: projects.length,
            chats: chats.length,
            messages: importedMessages,
        };
    }
    ensureProject(projectPath) {
        const localPath = normalizePath(projectPath);
        const projectId = localPath ? hashId(localPath) : "default-project";
        const name = localPath ? localPath.split("/").filter(Boolean).pop() ?? "Project" : "General";
        const existing = this.projects.get(projectId);
        const now = new Date().toISOString();
        const updated = {
            id: projectId,
            name,
            localPath,
            lastUpdatedAt: now,
        };
        this.projects.set(projectId, existing ? { ...existing, ...updated } : updated);
        return this.projects.get(projectId);
    }
    upsertProject(project) {
        const existing = this.projects.get(project.id);
        const normalized = {
            id: project.id,
            name: project.name,
            localPath: normalizePath(project.localPath),
            lastUpdatedAt: normalizeTimestamp(project.lastUpdatedAt),
        };
        if (!existing) {
            this.projects.set(project.id, normalized);
            return;
        }
        this.projects.set(project.id, {
            ...existing,
            ...normalized,
            lastUpdatedAt: maxTimestamp(existing.lastUpdatedAt, normalized.lastUpdatedAt),
        });
    }
    upsertChat(chat) {
        const existing = this.chats.get(chat.id);
        const normalized = {
            id: chat.id,
            projectId: chat.projectId,
            title: String(chat.title ?? "New Chat"),
            lastUpdatedAt: normalizeTimestamp(chat.lastUpdatedAt),
        };
        if (!existing) {
            this.chats.set(chat.id, normalized);
        }
        else {
            this.chats.set(chat.id, {
                ...existing,
                ...normalized,
                lastUpdatedAt: maxTimestamp(existing.lastUpdatedAt, normalized.lastUpdatedAt),
            });
        }
        const project = this.projects.get(normalized.projectId);
        if (project) {
            this.projects.set(normalized.projectId, {
                ...project,
                lastUpdatedAt: maxTimestamp(project.lastUpdatedAt, normalized.lastUpdatedAt),
            });
        }
    }
    upsertMessage(chatId, message) {
        const list = this.messagesByChat.get(chatId) ?? [];
        const existingIndex = list.findIndex((entry) => entry.id === message.id);
        if (existingIndex >= 0) {
            list[existingIndex] = message;
        }
        else {
            list.push(message);
        }
        list.sort((lhs, rhs) => lhs.createdAt.localeCompare(rhs.createdAt));
        this.messagesByChat.set(chatId, list);
        const chat = this.chats.get(chatId);
        if (chat) {
            this.chats.set(chatId, {
                ...chat,
                lastUpdatedAt: maxTimestamp(chat.lastUpdatedAt, message.createdAt),
            });
        }
    }
    ensureChat(chatId, projectId, titleSeed) {
        const existing = this.chats.get(chatId);
        const now = new Date().toISOString();
        const fallbackTitle = createChatTitle(titleSeed);
        const resolvedProjectId = existing?.projectId ?? projectId;
        const chat = {
            id: chatId,
            projectId: resolvedProjectId,
            title: existing?.title ?? fallbackTitle,
            lastUpdatedAt: now,
        };
        this.chats.set(chatId, chat);
        const project = this.projects.get(resolvedProjectId);
        if (project) {
            this.projects.set(resolvedProjectId, { ...project, lastUpdatedAt: now });
        }
    }
    pushMessage(chatId, role, text) {
        const list = this.messagesByChat.get(chatId) ?? [];
        list.push({ id: randomUUID(), role, text, createdAt: new Date().toISOString() });
        this.messagesByChat.set(chatId, list);
        const chat = this.chats.get(chatId);
        if (chat) {
            this.chats.set(chatId, { ...chat, lastUpdatedAt: new Date().toISOString() });
        }
    }
    persist() {
        const messagesByChat = {};
        for (const [chatId, messages] of this.messagesByChat.entries()) {
            messagesByChat[chatId] = messages;
        }
        saveState({
            projects: Array.from(this.projects.values()),
            chats: Array.from(this.chats.values()),
            messagesByChat,
        });
    }
}
export const companionChatStore = new CompanionChatStore();
function normalizeChatId(chatId, projectPath) {
    const trimmedChat = String(chatId ?? "").trim();
    if (trimmedChat)
        return trimmedChat;
    const normalizedPath = normalizePath(projectPath);
    return normalizedPath ? `chat-${hashId(normalizedPath)}-default` : "chat-default";
}
function normalizePath(projectPath) {
    return String(projectPath ?? "").trim();
}
function hashId(value) {
    return createHash("sha1").update(value).digest("hex").slice(0, 16);
}
function createChatTitle(seed) {
    const cleaned = seed.replace(/\s+/g, " ").trim();
    if (!cleaned)
        return "New Chat";
    return cleaned.length <= 48 ? cleaned : `${cleaned.slice(0, 45)}...`;
}
function normalizeTimestamp(input) {
    const value = String(input ?? "").trim();
    if (!value)
        return new Date().toISOString();
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? new Date(parsed).toISOString() : new Date().toISOString();
}
function maxTimestamp(lhs, rhs) {
    return lhs.localeCompare(rhs) >= 0 ? lhs : rhs;
}
function resolveStateFilePath() {
    const currentFile = fileURLToPath(import.meta.url);
    const currentDir = dirname(currentFile);
    const dataDir = join(currentDir, "..", "..", "data");
    return { dataDir, stateFilePath: join(dataDir, "companion-chat-state.json") };
}
function loadState() {
    const { stateFilePath } = resolveStateFilePath();
    if (!existsSync(stateFilePath))
        return defaultState;
    try {
        return { ...defaultState, ...JSON.parse(readFileSync(stateFilePath, "utf8")) };
    }
    catch {
        return defaultState;
    }
}
function saveState(state) {
    const { dataDir, stateFilePath } = resolveStateFilePath();
    mkdirSync(dataDir, { recursive: true });
    writeFileSync(stateFilePath, JSON.stringify(state, null, 2), "utf8");
}
