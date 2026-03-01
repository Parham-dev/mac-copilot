import { approveAll } from "@github/copilot-sdk";
import { mkdirSync } from "node:fs";
import { buildSessionHooks } from "./copilotSessionHooks.js";
import { resolveToolPolicy } from "./agentToolPolicyRegistry.js";
import { buildCustomTools } from "./copilotCustomTools.js";
import { buildConfiguredMCPServers, buildSessionIdentifier, discoverDefaultSkillDirectories, normalizeChatKey, normalizeStringListEnv, sameAllowedTools, sameStringList, selectAllowedTools, } from "./copilotSessionManagerHelpers.js";
import { resolveSkillSelection } from "./copilotSkillResolver.js";
const DEFAULT_BACKGROUND_COMPACTION_THRESHOLD = 120_000;
const DEFAULT_BUFFER_EXHAUSTION_THRESHOLD = 200_000;
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
            skillDirectories: this.lastSessionState?.skillDirectories ?? null,
            disabledSkills: this.lastSessionState?.disabledSkills ?? null,
            executionContext: this.lastSessionState?.executionContext ?? null,
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
            throw new Error(`Required agent skills are missing: ${resolvedSkills.missingRequiredSkills.join(", ")}. `
                + `Ensure skills are bundled under skills/shared or skills/agents/${requestedExecutionContext.agentID}.`);
        }
        const requestedToolPolicy = resolveToolPolicy(requestedExecutionContext);
        const chatKey = normalizeChatKey(args.chatID, requestedWorkingDirectory ?? undefined);
        const existing = this.sessionByChatKey.get(chatKey);
        console.log("[CopilotForge][Session] ensure_context", JSON.stringify({
            chatKey,
            model: requestedModel,
            workingDirectory: requestedWorkingDirectory,
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
            && existing.workingDirectory === requestedWorkingDirectory
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
            }
            catch {
            }
        }
        const state = await createOrResumeSessionForContext(client, {
            chatKey,
            model: requestedModel,
            workingDirectory: requestedWorkingDirectory,
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
    }
}
function readPositiveIntegerEnv(name, fallback) {
    const raw = String(process.env[name] ?? "").trim();
    if (!raw) {
        return fallback;
    }
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
async function createOrResumeSessionForContext(client, args) {
    if (!client) {
        throw new Error("Copilot client is not initialized.");
    }
    if (args.workingDirectory) {
        mkdirSync(args.workingDirectory, { recursive: true });
    }
    const sessionId = buildSessionIdentifier(args.chatKey);
    const backgroundCompactionThreshold = readPositiveIntegerEnv("COPILOTFORGE_BACKGROUND_COMPACTION_THRESHOLD", DEFAULT_BACKGROUND_COMPACTION_THRESHOLD);
    const bufferExhaustionThreshold = readPositiveIntegerEnv("COPILOTFORGE_BUFFER_EXHAUSTION_THRESHOLD", DEFAULT_BUFFER_EXHAUSTION_THRESHOLD);
    const mcpServers = buildConfiguredMCPServers();
    const resolvedToolPolicy = resolveToolPolicy(args.executionContext);
    const customTools = buildCustomTools({
        chatKey: args.chatKey,
        workingDirectory: args.workingDirectory,
        executionContext: args.executionContext,
        policy: resolvedToolPolicy,
    });
    const config = {
        sessionId,
        model: args.model,
        streaming: true,
        onPermissionRequest: approveAll,
        ...(customTools ? { tools: customTools } : {}),
        hooks: buildSessionHooks({
            chatKey: args.chatKey,
            workingDirectory: args.workingDirectory,
            allowedTools: args.allowedTools,
            executionContext: args.executionContext,
        }),
        infiniteSessions: {
            enabled: true,
            backgroundCompactionThreshold,
            bufferExhaustionThreshold,
        },
        ...(mcpServers ? { mcpServers } : {}),
        ...(args.workingDirectory ? { workingDirectory: args.workingDirectory } : {}),
        ...(args.nativeAvailableTools ? { availableTools: args.nativeAvailableTools } : {}),
        ...(args.skillDirectories ? { skillDirectories: args.skillDirectories } : {}),
        ...(args.disabledSkills ? { disabledSkills: args.disabledSkills } : {}),
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
        skillDirectories: args.skillDirectories,
        disabledSkills: args.disabledSkills,
        executionContext: args.executionContext,
    };
}
