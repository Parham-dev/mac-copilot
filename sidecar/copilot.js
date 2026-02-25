import { CopilotClient } from "@github/copilot-sdk";

let client = null;
let session = null;

export function isAuthenticated() {
  return session !== null;
}

export async function startClient(token) {
  process.env.GITHUB_TOKEN = token;
  client = new CopilotClient();
  await client.start();
  session = await client.createSession({ model: "gpt-4o" });
}

export function clearSession() {
  client = null;
  session = null;
}

export async function sendPrompt(prompt, onChunk) {
  if (!session) {
    onChunk("Not authenticated yet. Please complete GitHub auth first.");
    return;
  }

  await session.send({ prompt }, { onChunk });
}
