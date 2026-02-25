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
    session = await client.createSession({ model: "gpt-4o" });
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

  await session.send({ prompt }, { onChunk });
}
