import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type MessageRole = "user" | "assistant";
type CompanionMessage = {
  id: string;
  role: MessageRole;
  text: string;
  createdAt: string;
};
type CompanionChat = {
  id: string;
  projectId: string;
  title: string;
  lastUpdatedAt: string;
};
type CompanionProject = {
  id: string;
  name: string;
  localPath: string;
  lastUpdatedAt: string;
};
type PersistedChatState = {
  projects: CompanionProject[];
  chats: CompanionChat[];
  messagesByChat: Record<string, CompanionMessage[]>;
};

type CompanionSnapshot = {
  projects?: CompanionProject[];
  chats?: CompanionChat[];
  messages?: Array<CompanionMessage & { chatId: string }>;
};

const defaultState: PersistedChatState = {
  projects: [],
  chats: [],
  messagesByChat: {},
};

export class CompanionChatStore {
  private readonly projects = new Map<string, CompanionProject>();
  private readonly chats = new Map<string, CompanionChat>();
  private readonly messagesByChat = new Map<string, CompanionMessage[]>();

  constructor() {
    const state = loadState();
    for (const project of state.projects) this.projects.set(project.id, project);
    for (const chat of state.chats) this.chats.set(chat.id, chat);
    for (const [chatId, messages] of Object.entries(state.messagesByChat)) {
      this.messagesByChat.set(chatId, messages);
    }
  }

  recordUserPrompt(input: { chatId?: string; projectPath?: string; prompt: string }) {
    const chatId = normalizeChatId(input.chatId, input.projectPath);
    const project = this.ensureProject(input.projectPath);
    this.ensureChat(chatId, project.id, input.prompt);
    this.pushMessage(chatId, "user", input.prompt);
    this.persist();
    return chatId;
  }

  recordAssistantResponse(chatId: string, text: string) {
    if (!text.trim()) return;
    this.ensureChat(chatId, this.ensureProject(undefined).id, text);
    this.pushMessage(chatId, "assistant", text);
    this.persist();
  }

  listProjects() {
    return Array.from(this.projects.values()).sort((a, b) => b.lastUpdatedAt.localeCompare(a.lastUpdatedAt));
  }

  listChats(projectId: string) {
    return Array.from(this.chats.values())
      .filter((chat) => chat.projectId === projectId)
      .sort((a, b) => b.lastUpdatedAt.localeCompare(a.lastUpdatedAt));
  }

  listMessages(chatId: string, cursor?: string, limit = 50) {
    const messages = this.messagesByChat.get(chatId) ?? [];
    const clampedLimit = Math.max(1, Math.min(limit, 200));
    const start = Number.isFinite(Number(cursor)) ? Math.max(0, Number(cursor)) : 0;
    const slice = messages.slice(start, start + clampedLimit);
    const nextCursor = start + clampedLimit < messages.length ? String(start + clampedLimit) : null;
    return { messages: slice, nextCursor };
  }

  chatById(chatId: string) {
    return this.chats.get(chatId) ?? null;
  }

  importSnapshot(snapshot: CompanionSnapshot) {
    const projects = Array.isArray(snapshot.projects) ? snapshot.projects : [];
    const chats = Array.isArray(snapshot.chats) ? snapshot.chats : [];
    const messages = Array.isArray(snapshot.messages) ? snapshot.messages : [];

    for (const project of projects) {
      if (!project.id || !project.name) continue;
      this.upsertProject(project);
    }

    for (const chat of chats) {
      if (!chat.id || !chat.projectId) continue;
      this.upsertChat(chat);
    }

    let importedMessages = 0;
    for (const message of messages) {
      if (!message.chatId || !message.id) continue;
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

  private ensureProject(projectPath?: string) {
    const localPath = normalizePath(projectPath);
    const projectId = localPath ? hashId(localPath) : "default-project";
    const name = localPath ? localPath.split("/").filter(Boolean).pop() ?? "Project" : "General";

    const existing = this.projects.get(projectId);
    const now = new Date().toISOString();
    const updated: CompanionProject = {
      id: projectId,
      name,
      localPath,
      lastUpdatedAt: now,
    };

    this.projects.set(projectId, existing ? { ...existing, ...updated } : updated);
    return this.projects.get(projectId)!;
  }

  private upsertProject(project: CompanionProject) {
    const existing = this.projects.get(project.id);
    const normalized: CompanionProject = {
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

  private upsertChat(chat: CompanionChat) {
    const existing = this.chats.get(chat.id);
    const normalized: CompanionChat = {
      id: chat.id,
      projectId: chat.projectId,
      title: String(chat.title ?? "New Chat"),
      lastUpdatedAt: normalizeTimestamp(chat.lastUpdatedAt),
    };

    if (!existing) {
      this.chats.set(chat.id, normalized);
    } else {
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

  private upsertMessage(chatId: string, message: CompanionMessage) {
    const list = this.messagesByChat.get(chatId) ?? [];
    const existingIndex = list.findIndex((entry) => entry.id === message.id);

    if (existingIndex >= 0) {
      list[existingIndex] = message;
    } else {
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

  private ensureChat(chatId: string, projectId: string, titleSeed: string) {
    const existing = this.chats.get(chatId);
    const now = new Date().toISOString();
    const fallbackTitle = createChatTitle(titleSeed);

    const resolvedProjectId = existing?.projectId ?? projectId;
    const chat: CompanionChat = {
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

  private pushMessage(chatId: string, role: MessageRole, text: string) {
    const list = this.messagesByChat.get(chatId) ?? [];
    list.push({ id: randomUUID(), role, text, createdAt: new Date().toISOString() });
    this.messagesByChat.set(chatId, list);

    const chat = this.chats.get(chatId);
    if (chat) {
      this.chats.set(chatId, { ...chat, lastUpdatedAt: new Date().toISOString() });
    }
  }

  private persist() {
    const messagesByChat: Record<string, CompanionMessage[]> = {};
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

function normalizeChatId(chatId?: string, projectPath?: string) {
  const trimmedChat = String(chatId ?? "").trim();
  if (trimmedChat) return trimmedChat;
  const normalizedPath = normalizePath(projectPath);
  return normalizedPath ? `chat-${hashId(normalizedPath)}-default` : "chat-default";
}

function normalizePath(projectPath?: string) {
  return String(projectPath ?? "").trim();
}

function hashId(value: string) {
  return createHash("sha1").update(value).digest("hex").slice(0, 16);
}

function createChatTitle(seed: string) {
  const cleaned = seed.replace(/\s+/g, " ").trim();
  if (!cleaned) return "New Chat";
  return cleaned.length <= 48 ? cleaned : `${cleaned.slice(0, 45)}...`;
}

function normalizeTimestamp(input: string | undefined) {
  const value = String(input ?? "").trim();
  if (!value) return new Date().toISOString();
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : new Date().toISOString();
}

function maxTimestamp(lhs: string, rhs: string) {
  return lhs.localeCompare(rhs) >= 0 ? lhs : rhs;
}

function resolveStateFilePath() {
  const currentFile = fileURLToPath(import.meta.url);
  const currentDir = dirname(currentFile);
  const dataDir = join(currentDir, "..", "..", "data");
  return { dataDir, stateFilePath: join(dataDir, "companion-chat-state.json") };
}

function loadState(): PersistedChatState {
  const { stateFilePath } = resolveStateFilePath();
  if (!existsSync(stateFilePath)) return defaultState;

  try {
    return { ...defaultState, ...(JSON.parse(readFileSync(stateFilePath, "utf8")) as PersistedChatState) };
  } catch {
    return defaultState;
  }
}

function saveState(state: PersistedChatState) {
  const { dataDir, stateFilePath } = resolveStateFilePath();
  mkdirSync(dataDir, { recursive: true });
  writeFileSync(stateFilePath, JSON.stringify(state, null, 2), "utf8");
}
