import { CopilotClient, approveAll } from "@github/copilot-sdk";
import { mkdirSync } from "node:fs";

let client = null;
let session = null;
let lastAuthError = null;
let lastAuthAt = null;
let activeModel = "gpt-5";
let activeWorkingDirectory = null;

export function isAuthenticated() {
  return session !== null;
}

export async function startClient(token) {
  try {
    process.env.GITHUB_TOKEN = token;
    client = new CopilotClient();
    await client.start();
    session = await client.createSession({
      model: activeModel,
      streaming: true,
      onPermissionRequest: approveAll,
      ...(activeWorkingDirectory ? { workingDirectory: activeWorkingDirectory } : {}),
    });
    lastAuthError = null;
    lastAuthAt = new Date().toISOString();
  } catch (error) {
    lastAuthError = String(error);
    client = null;
    session = null;
    throw error;
  }
}

export function clearSession() {
  client = null;
  session = null;
  activeModel = "gpt-5";
  activeWorkingDirectory = null;
}

export function getCopilotReport() {
  return {
    sessionReady: session !== null,
    activeModel,
    activeWorkingDirectory,
    lastAuthAt,
    lastAuthError,
    usingGitHubToken: Boolean(process.env.GITHUB_TOKEN),
  };
}

async function ensureSessionForContext(model, projectPath) {
  const requested = typeof model === "string" && model.trim().length > 0 ? model.trim() : "gpt-5";
  const requestedWorkingDirectory = typeof projectPath === "string" && projectPath.trim().length > 0
    ? projectPath.trim()
    : null;

  if (session && activeModel === requested && activeWorkingDirectory === requestedWorkingDirectory) {
    return;
  }

  if (!client) {
    throw new Error("Copilot client is not initialized.");
  }

  if (requestedWorkingDirectory) {
    mkdirSync(requestedWorkingDirectory, { recursive: true });
  }

  session = await client.createSession({
    model: requested,
    streaming: true,
    onPermissionRequest: approveAll,
    ...(requestedWorkingDirectory ? { workingDirectory: requestedWorkingDirectory } : {}),
  });
  activeModel = requested;
  activeWorkingDirectory = requestedWorkingDirectory;
}

export async function listAvailableModels() {
  if (!client || typeof client.listModels !== "function") {
    return ["gpt-5"];
  }

  try {
    const raw = await client.listModels();
    if (!Array.isArray(raw)) {
      return ["gpt-5"];
    }

    const ids = raw
      .map((item) => {
        if (typeof item === "string") {
          return item;
        }
        if (item && typeof item === "object") {
          if (typeof item.id === "string") {
            return item.id;
          }
          if (typeof item.model === "string") {
            return item.model;
          }
        }
        return null;
      })
      .filter((value) => typeof value === "string" && value.length > 0);

    const unique = Array.from(new Set(ids));
    return unique.length > 0 ? unique : ["gpt-5"];
  } catch {
    return ["gpt-5"];
  }
}

export async function sendPrompt(prompt, model, projectPath, onChunk) {
  if (!session) {
    onChunk("Not authenticated yet. Please complete GitHub auth first.");
    return;
  }

  const trimmedPrompt = String(prompt ?? "").trim();
  if (!trimmedPrompt) {
    onChunk("Please enter a prompt.");
    return;
  }

  await ensureSessionForContext(model, projectPath);

  let sawAnyOutput = false;
  let sawDeltaOutput = false;

  let resolveDone;
  let rejectDone;
  const done = new Promise((resolve, reject) => {
    resolveDone = resolve;
    rejectDone = reject;
  });

  const timeoutMs = 120000;
  const timeoutId = setTimeout(() => {
    rejectDone(new Error(`Copilot response timed out after ${timeoutMs}ms`));
  }, timeoutMs);

  const unsubscribeDelta = session.on("assistant.message_delta", (event) => {
    const delta = event?.data?.deltaContent;
    if (typeof delta === "string" && delta.length > 0) {
      sawAnyOutput = true;
      sawDeltaOutput = true;
      onChunk(delta);
    }
  });

  const unsubscribeFinal = session.on("assistant.message", (event) => {
    const content = event?.data?.content;
    if (!sawDeltaOutput && typeof content === "string" && content.length > 0) {
      sawAnyOutput = true;
      onChunk(content);
    }
  });

  const unsubscribeIdle = session.on("session.idle", () => {
    resolveDone();
  });

  try {
    await session.send({ prompt: trimmedPrompt, mode: "immediate" });
    await done;

    if (!sawAnyOutput) {
      onChunk("Copilot returned no text output for this request.");
    }
  } finally {
    clearTimeout(timeoutId);
    unsubscribeDelta();
    unsubscribeFinal();
    unsubscribeIdle();
  }
}
