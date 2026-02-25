import { CopilotClient } from "@github/copilot-sdk";

let client = null;
let session = null;
let lastAuthError = null;
let lastAuthAt = null;
let activeModel = "gpt-5";

export function isAuthenticated() {
  return session !== null;
}

export async function startClient(token) {
  try {
    process.env.GITHUB_TOKEN = token;
    client = new CopilotClient();
    await client.start();
    session = await client.createSession({ model: activeModel, streaming: true });
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
}

export function getCopilotReport() {
  return {
    sessionReady: session !== null,
    activeModel,
    lastAuthAt,
    lastAuthError,
    usingGitHubToken: Boolean(process.env.GITHUB_TOKEN),
  };
}

async function ensureSessionForModel(model) {
  const requested = typeof model === "string" && model.trim().length > 0 ? model.trim() : "gpt-5";
  if (session && activeModel === requested) {
    return;
  }

  if (!client) {
    throw new Error("Copilot client is not initialized.");
  }

  session = await client.createSession({ model: requested, streaming: true });
  activeModel = requested;
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

export async function sendPrompt(prompt, model, onChunk) {
  if (!session) {
    onChunk("Not authenticated yet. Please complete GitHub auth first.");
    return;
  }

  const trimmedPrompt = String(prompt ?? "").trim();
  if (!trimmedPrompt) {
    onChunk("Please enter a prompt.");
    return;
  }

  await ensureSessionForModel(model);

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
