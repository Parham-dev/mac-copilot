import { CopilotClient } from "@github/copilot-sdk";
import { listModelCatalog } from "./copilotModelCatalog.js";
import { streamPromptWithSession } from "./copilotPromptStreaming.js";
import { CopilotSessionManager } from "./copilotSessionManager.js";

let client: CopilotClient | null = null;
let lastAuthError: string | null = null;
let lastAuthAt: string | null = null;
const sessionManager = new CopilotSessionManager();

function ensureCopilotShellPath() {
  const currentPath = String(process.env.PATH ?? "");
  const currentNodeDirectory = process.execPath
    ? process.execPath.split("/").slice(0, -1).join("/")
    : "";

  const pathSegments = currentPath.split(":").filter((entry) => entry.length > 0);
  const normalized: string[] = [];

  if (currentNodeDirectory.length > 0) {
    normalized.push(currentNodeDirectory);
  }

  for (const segment of pathSegments) {
    if (!normalized.includes(segment)) {
      normalized.push(segment);
    }
  }

  const requiredSegments = [
    "/opt/homebrew/bin",
    "/opt/homebrew/opt/node@22/bin",
    "/opt/homebrew/opt/node/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin",
  ];

  const existing = new Set(normalized);
  for (const segment of requiredSegments) {
    existing.add(segment);
  }

  process.env.PATH = Array.from(existing).join(":");
}

export function isAuthenticated() {
  return client !== null;
}

export async function startClient(token?: string) {
  try {
    process.env.GITHUB_TOKEN = token;
    ensureCopilotShellPath();
    sessionManager.reset();
    client = new CopilotClient();
    await client.start();
    lastAuthError = null;
    lastAuthAt = new Date().toISOString();
  } catch (error) {
    lastAuthError = String(error);
    client = null;
    sessionManager.reset();
    throw error;
  }
}

export function clearSession() {
  client = null;
  sessionManager.reset();
}

export function getCopilotReport() {
  const snapshot = sessionManager.activeSnapshot();
  return {
    sessionReady: sessionManager.hasActiveSessions(),
    activeModel: snapshot.model,
    activeWorkingDirectory: snapshot.workingDirectory,
    activeAvailableTools: snapshot.availableTools,
    activeSessionCount: sessionManager.sessionCount(),
    lastAuthAt,
    lastAuthError,
    usingGitHubToken: Boolean(process.env.GITHUB_TOKEN),
  };
}

export async function listAvailableModels() {
  return listModelCatalog(client);
}

export async function sendPrompt(
  prompt: string,
  chatID: string | undefined,
  model: string | undefined,
  projectPath: string | undefined,
  allowedTools: string[] | null | undefined,
  requestId: string | undefined,
  onEvent: (event: Record<string, unknown>) => void
) {
  if (!client) {
    onEvent({ type: "text", text: "Not authenticated yet. Please complete GitHub auth first." });
    return;
  }

  const activeSession = await sessionManager.ensureSessionForContext(client, {
    chatID,
    model,
    projectPath,
    allowedTools: allowedTools ?? null,
  });

  const debugLabel = requestId?.trim().length ? requestId.trim() : chatID;
  await streamPromptWithSession(activeSession, prompt, onEvent, debugLabel);
}
