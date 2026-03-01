import { CopilotClient, approveAll } from "@github/copilot-sdk";
import { mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { buildSessionHooks } from "./copilotSessionHooks.js";
import type { AgentExecutionContext } from "./agentToolPolicyRegistry.js";
import { resolveToolPolicy } from "./agentToolPolicyRegistry.js";
import { buildCustomTools } from "./copilotCustomTools.js";
import {
  buildConfiguredMCPServers,
  buildSessionIdentifier,
  discoverDefaultSkillDirectories,
  normalizeChatKey,
  normalizeStringListEnv,
  sameAllowedTools,
  sameStringList,
  selectAllowedTools,
} from "./copilotSessionManagerHelpers.js";
import { resolveSkillSelection } from "./copilotSkillResolver.js";

const DEFAULT_BACKGROUND_COMPACTION_THRESHOLD = 120_000;
const DEFAULT_BUFFER_EXHAUSTION_THRESHOLD = 200_000;
const DEFAULT_AGENT_RUNS_ROOT = resolve(homedir(), "Library", "Application Support", "CopilotForge", "agent-runs");

export type SessionState = {
  chatKey: string;
  sessionId: string;
  session: any;
  model: string | null;
  workingDirectory: string | null;
  availableTools: string[] | null;
  skillDirectories: string[] | null;
  disabledSkills: string[] | null;
  executionContext: AgentExecutionContext | null;
};

type EnsureSessionArgs = {
  chatID?: string;
  model?: string;
  projectPath?: string;
  allowedTools?: string[] | null;
  executionContext?: AgentExecutionContext | null;
};

export class CopilotSessionManager {
  private readonly sessionByChatKey = new Map<string, SessionState>();
  private readonly ensureChainByChatKey = new Map<string, Promise<unknown>>();
  private lastSessionState: SessionState | null = null;

  reset() {
    this.sessionByChatKey.clear();
    this.ensureChainByChatKey.clear();
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
      executionContext: this.lastSessionState?.executionContext ?? null,
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
    const selectedTools = selectAllowedTools(args.allowedTools);
    const requestedAvailableTools = selectedTools.requestedAllowedTools;
    const configuredBaseSkillDirectories = normalizeStringListEnv("COPILOTFORGE_SKILL_DIRECTORIES")
      ?? discoverDefaultSkillDirectories();
    const requestedExecutionContext = args.executionContext ?? null;
    const requestedDisabledSkills = normalizeStringListEnv("COPILOTFORGE_DISABLED_SKILLS");
    const resolvedSkills = resolveSkillSelection({
      baseSkillDirectories: configuredBaseSkillDirectories,
      envDisabledSkills: requestedDisabledSkills,
      executionContext: requestedExecutionContext,
    });

    if (requestedExecutionContext?.requireSkills && resolvedSkills.missingRequiredSkills.length > 0) {
      throw new Error(
        `Required agent skills are missing: ${resolvedSkills.missingRequiredSkills.join(", ")}. `
        + `Ensure skills are bundled under skills/shared or skills/agents/${requestedExecutionContext.agentID}.`
      );
    }

    const requestedToolPolicy = resolveToolPolicy(requestedExecutionContext);
    const chatKey = normalizeChatKey(args.chatID, requestedWorkingDirectory ?? undefined);

    return this.enqueueEnsure(chatKey, async () => {
      const requestedSessionID = buildSessionIdentifier(chatKey);
      const resolvedWorkingDirectory = resolveWorkingDirectory({
        requestedWorkingDirectory,
        executionContext: requestedExecutionContext,
        sessionId: requestedSessionID,
      });
      const existing = this.sessionByChatKey.get(chatKey);

      console.log("[CopilotForge][Session] ensure_context", JSON.stringify({
        chatKey,
        model: requestedModel,
        workingDirectory: resolvedWorkingDirectory,
        requestedAllowedToolsCount: requestedAvailableTools?.length ?? null,
        requestedAllowedToolsSample: requestedAvailableTools?.slice(0, 8) ?? null,
        nativeAvailableToolsCount: selectedTools.nativeAvailableTools?.length ?? null,
        nativeAvailableToolsSample: selectedTools.nativeAvailableTools?.slice(0, 8) ?? null,
        skillSelectionMode: resolvedSkills.mode,
        selectedSkillNames: resolvedSkills.selectedSkillNames,
        missingRequiredSkills: resolvedSkills.missingRequiredSkills,
        skillDirectoriesCount: resolvedSkills.skillDirectories?.length ?? null,
        skillDirectoriesSample: resolvedSkills.skillDirectories?.slice(0, 4) ?? null,
        disabledSkillsCount: resolvedSkills.disabledSkills?.length ?? null,
        disabledSkillsSample: resolvedSkills.disabledSkills?.slice(0, 8) ?? null,
        executionContext: requestedExecutionContext,
        policyProfile: requestedToolPolicy.profileName,
        hasExistingSession: Boolean(existing),
      }));

      if (existing
          && existing.model === requestedModel
          && existing.workingDirectory === resolvedWorkingDirectory
          && sameAllowedTools(existing.availableTools, requestedAvailableTools)
          && sameStringList(existing.skillDirectories, resolvedSkills.skillDirectories)
          && sameStringList(existing.disabledSkills, resolvedSkills.disabledSkills)
          && JSON.stringify(existing.executionContext) === JSON.stringify(requestedExecutionContext)) {
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
        workingDirectory: resolvedWorkingDirectory,
        allowedTools: requestedAvailableTools,
        nativeAvailableTools: selectedTools.nativeAvailableTools,
        skillDirectories: resolvedSkills.skillDirectories,
        disabledSkills: resolvedSkills.disabledSkills,
        executionContext: requestedExecutionContext,
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
    });
  }

  private async enqueueEnsure<T>(chatKey: string, operation: () => Promise<T>): Promise<T> {
    const previous = this.ensureChainByChatKey.get(chatKey) ?? Promise.resolve();
    const current = previous
      .catch(() => undefined)
      .then(async () => operation());

    this.ensureChainByChatKey.set(chatKey, current);

    try {
      return await current;
    } finally {
      if (this.ensureChainByChatKey.get(chatKey) === current) {
        this.ensureChainByChatKey.delete(chatKey);
      }
    }
  }
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
    nativeAvailableTools: string[] | null;
    skillDirectories: string[] | null;
    disabledSkills: string[] | null;
    executionContext: AgentExecutionContext | null;
  }
): Promise<SessionState> {
  if (!client) {
    throw new Error("Copilot client is not initialized.");
  }

  const sessionId = buildSessionIdentifier(args.chatKey);
  const workingDirectory = ensureSessionWorkingDirectory(args.workingDirectory, args.executionContext);
  const backgroundCompactionThreshold = readPositiveIntegerEnv(
    "COPILOTFORGE_BACKGROUND_COMPACTION_THRESHOLD",
    DEFAULT_BACKGROUND_COMPACTION_THRESHOLD
  );
  const bufferExhaustionThreshold = readPositiveIntegerEnv(
    "COPILOTFORGE_BUFFER_EXHAUSTION_THRESHOLD",
    DEFAULT_BUFFER_EXHAUSTION_THRESHOLD
  );
  const mcpServers = buildConfiguredMCPServers();
  const resolvedToolPolicy = resolveToolPolicy(args.executionContext);
  const customTools = buildCustomTools({
    chatKey: args.chatKey,
    workingDirectory,
    executionContext: args.executionContext,
    policy: resolvedToolPolicy,
  });

  const config: Record<string, unknown> = {
    sessionId,
    model: args.model,
    streaming: true,
    onPermissionRequest: approveAll,
    ...(customTools ? { tools: customTools } : {}),
    hooks: buildSessionHooks({
      chatKey: args.chatKey,
      workingDirectory,
      allowedTools: args.allowedTools,
      executionContext: args.executionContext,
    }),
    infiniteSessions: {
      enabled: true,
      backgroundCompactionThreshold,
      bufferExhaustionThreshold,
    },
    ...(mcpServers ? { mcpServers } : {}),
    ...(workingDirectory ? { workingDirectory } : {}),
    ...(args.nativeAvailableTools ? { availableTools: args.nativeAvailableTools } : {}),
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
    workingDirectory,
    availableTools: args.allowedTools,
    skillDirectories: args.skillDirectories,
    disabledSkills: args.disabledSkills,
    executionContext: args.executionContext,
  };
}

function isAgentsExecutionContext(executionContext: AgentExecutionContext | null) {
  return executionContext?.feature?.trim() === "agents";
}

function resolveWorkingDirectory(args: {
  requestedWorkingDirectory: string | null;
  executionContext: AgentExecutionContext | null;
  sessionId: string;
}) {
  if (!isAgentsExecutionContext(args.executionContext)) {
    return args.requestedWorkingDirectory;
  }

  const configuredRoot = String(process.env.COPILOTFORGE_AGENT_RUNS_ROOT ?? "").trim();
  const agentRunsRoot = configuredRoot.length > 0 ? configuredRoot : DEFAULT_AGENT_RUNS_ROOT;
  return resolve(agentRunsRoot, args.sessionId);
}

function ensureSessionWorkingDirectory(
  workingDirectory: string | null,
  executionContext: AgentExecutionContext | null
) {
  if (workingDirectory && isAgentsExecutionContext(executionContext)) {
    mkdirSync(workingDirectory, { recursive: true });
  }

  return workingDirectory;
}
