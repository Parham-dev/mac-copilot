import { CopilotClient } from "@github/copilot-sdk";

let client = null;
let session = null;
let lastAuthError = null;
let lastAuthAt = null;

export function isAuthenticated() {
  return session !== null;
}

export async function startClient(token) {
  try {
    process.env.GITHUB_TOKEN = token;
    client = new CopilotClient();
    await client.start();
    session = await client.createSession({ model: "gpt-5", streaming: true });
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
}

export function getCopilotReport() {
  return {
    sessionReady: session !== null,
    lastAuthAt,
    lastAuthError,
    usingGitHubToken: Boolean(process.env.GITHUB_TOKEN),
  };
}

export async function sendPrompt(prompt, onChunk) {
  if (!session) {
    onChunk("Not authenticated yet. Please complete GitHub auth first.");
    return;
  }

  const trimmedPrompt = String(prompt ?? "").trim();
  if (!trimmedPrompt) {
    onChunk("Please enter a prompt.");
    return;
  }

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
