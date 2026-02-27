import { CopilotClient, approveAll } from "@github/copilot-sdk";
import { mkdirSync } from "node:fs";
import { buildSessionHooks } from "./copilotSessionHooks.js";

const DEFAULT_BACKGROUND_COMPACTION_THRESHOLD = 120_000;
const DEFAULT_BUFFER_EXHAUSTION_THRESHOLD = 200_000;

export type SessionState = {
  chatKey: string;
  sessionId: string;
  session: any;
  model: string | null;
  workingDirectory: string | null;
  availableTools: string[] | null;
  skillDirectories: string[] | null;
  disabledSkills: string[] | null;
};

type EnsureSessionArgs = {
  chatID?: string;
  model?: string;
  projectPath?: string;
  allowedTools?: string[] | null;
};

export class CopilotSessionManager {
  private readonly sessionByChatKey = new Map<string, SessionState>();
  private lastSessionState: SessionState | null = null;

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
      skillDirectories: this.lastSessionState?.skillDirectories ?? null,
      disabledSkills: this.lastSessionState?.disabledSkills ?? null,
    };
  }

  async ensureSessionForContext(client: CopilotClient | null, args: EnsureSessionArgs) {
    const requestedModel = typeof args.model === "string" ? args.model.trim() : "";
    if (!requestedModel) {
      throw new Error("No model selected. Load models and choose one before sending a prompt.");
    }
    const requestedWorkingDirectory = typeof args.projectPath === "string" && args.projectPath.trim().length > 0
      ? args.projectPath.trim()
      : null;
    const requestedAvailableTools = normalizeAllowedTools(args.allowedTools);
    const requestedSkillDirectories = normalizeStringListEnv("COPILOTFORGE_SKILL_DIRECTORIES");
    const requestedDisabledSkills = normalizeStringListEnv("COPILOTFORGE_DISABLED_SKILLS");
    const chatKey = normalizeChatKey(args.chatID, requestedWorkingDirectory ?? undefined);
    const existing = this.sessionByChatKey.get(chatKey);

    console.log("[CopilotForge][Session] ensure_context", JSON.stringify({
      chatKey,
      model: requestedModel,
      workingDirectory: requestedWorkingDirectory,
      requestedAllowedToolsCount: requestedAvailableTools?.length ?? null,
      requestedAllowedToolsSample: requestedAvailableTools?.slice(0, 8) ?? null,
      hasExistingSession: Boolean(existing),
    }));

    if (existing
        && existing.model === requestedModel
        && existing.workingDirectory === requestedWorkingDirectory
        && sameAllowedTools(existing.availableTools, requestedAvailableTools)
        && sameStringList(existing.skillDirectories, requestedSkillDirectories)
        && sameStringList(existing.disabledSkills, requestedDisabledSkills)) {
      console.log("[CopilotForge][Session] reuse", JSON.stringify({
        chatKey,
        sessionId: existing.sessionId,
        allowedToolsCount: existing.availableTools?.length ?? null,
      }));
      this.lastSessionState = existing;
      return existing.session;
    }

    if (existing?.session && typeof existing.session.destroy === "function") {
      try {
        await existing.session.destroy();
      } catch {
      }
    }

    const state = await createOrResumeSessionForContext(client, {
      chatKey,
      model: requestedModel,
      workingDirectory: requestedWorkingDirectory,
      allowedTools: requestedAvailableTools,
      skillDirectories: requestedSkillDirectories,
      disabledSkills: requestedDisabledSkills,
    });

    this.sessionByChatKey.set(chatKey, state);
    this.lastSessionState = state;
    console.log("[CopilotForge][Session] active", JSON.stringify({
      chatKey,
      sessionId: state.sessionId,
      allowedToolsCount: state.availableTools?.length ?? null,
      allowedToolsSample: state.availableTools?.slice(0, 8) ?? null,
    }));
    return state.session;
  }
}

function normalizeAllowedTools(allowedTools?: string[] | null) {
  if (!Array.isArray(allowedTools)) {
    return null;
  }

  const normalized = Array.from(new Set(
    allowedTools
      .filter((entry) => typeof entry === "string")
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0)
  )).sort((lhs, rhs) => lhs.localeCompare(rhs));

  return normalized;
}

function normalizeStringListEnv(name: string) {
  const raw = String(process.env[name] ?? "").trim();
  if (!raw) {
    return null;
  }

  const normalized = Array.from(new Set(
    raw
      .split(",")
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0)
  )).sort((lhs, rhs) => lhs.localeCompare(rhs));

  return normalized.length > 0 ? normalized : null;
}

function sameAllowedTools(lhs: string[] | null, rhs: string[] | null) {
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

function sameStringList(lhs: string[] | null, rhs: string[] | null) {
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

function normalizeChatKey(chatID?: string, projectPath?: string) {
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

function buildSessionIdentifier(chatKey: string) {
  const sanitized = chatKey
    .replace(/[^a-zA-Z0-9_-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 96);
  const suffix = sanitized.length > 0 ? sanitized : "default";
  return `copilotforge-${suffix}`;
}

function readPositiveIntegerEnv(name: string, fallback: number) {
  const raw = String(process.env[name] ?? "").trim();
  if (!raw) {
    return fallback;
  }

  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

async function createOrResumeSessionForContext(
  client: CopilotClient | null,
  args: {
    chatKey: string;
    model: string;
    workingDirectory: string | null;
    allowedTools: string[] | null;
    skillDirectories: string[] | null;
    disabledSkills: string[] | null;
  }
): Promise<SessionState> {
  if (!client) {
    throw new Error("Copilot client is not initialized.");
  }

  if (args.workingDirectory) {
    mkdirSync(args.workingDirectory, { recursive: true });
  }

  const sessionId = buildSessionIdentifier(args.chatKey);
  const backgroundCompactionThreshold = readPositiveIntegerEnv(
    "COPILOTFORGE_BACKGROUND_COMPACTION_THRESHOLD",
    DEFAULT_BACKGROUND_COMPACTION_THRESHOLD
  );
  const bufferExhaustionThreshold = readPositiveIntegerEnv(
    "COPILOTFORGE_BUFFER_EXHAUSTION_THRESHOLD",
    DEFAULT_BUFFER_EXHAUSTION_THRESHOLD
  );

  const config: Record<string, unknown> = {
    sessionId,
    model: args.model,
    streaming: true,
    onPermissionRequest: approveAll,
    hooks: buildSessionHooks({
      chatKey: args.chatKey,
      workingDirectory: args.workingDirectory,
      allowedTools: args.allowedTools,
    }),
    infiniteSessions: {
      enabled: true,
      backgroundCompactionThreshold,
      bufferExhaustionThreshold,
    },
    ...(args.workingDirectory ? { workingDirectory: args.workingDirectory } : {}),
    ...(args.allowedTools ? { availableTools: args.allowedTools } : {}),
    ...(args.skillDirectories ? { skillDirectories: args.skillDirectories } : {}),
    ...(args.disabledSkills ? { disabledSkills: args.disabledSkills } : {}),
  };

  let createdSession: any;
  try {
    createdSession = await (client as any).resumeSession(sessionId, config);
  } catch {
    createdSession = await client.createSession(config as any);
  }

  return {
    chatKey: args.chatKey,
    sessionId,
    session: createdSession,
    model: args.model,
    workingDirectory: args.workingDirectory,
    availableTools: args.allowedTools,
    skillDirectories: args.skillDirectories,
    disabledSkills: args.disabledSkills,
  };
}
