import { CopilotClient, approveAll } from "@github/copilot-sdk";

function parseArgs(argv) {
  const result = {
    model: process.env.COPILOT_SDK_TEST_MODEL || "claude-haiku-4.5",
    tools: "none",
    prompt: "How many tools do you have in this session? List their exact names.",
    cwd: process.cwd(),
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--model" && argv[index + 1]) {
      result.model = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg === "--tools" && argv[index + 1]) {
      result.tools = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg === "--prompt" && argv[index + 1]) {
      result.prompt = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg === "--cwd" && argv[index + 1]) {
      result.cwd = argv[index + 1];
      index += 1;
      continue;
    }
  }

  return result;
}

function normalizeTools(raw) {
  const value = String(raw || "").trim().toLowerCase();
  if (!value || value === "none") {
    return [];
  }
  if (value === "all") {
    return null;
  }

  const normalized = Array.from(new Set(
    String(raw)
      .split(",")
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0)
  )).sort((lhs, rhs) => lhs.localeCompare(rhs));

  return normalized;
}

function onceIdle(session, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`Timed out waiting for session.idle after ${timeoutMs}ms`));
    }, timeoutMs);

    const unsubscribe = session.on("session.idle", () => {
      clearTimeout(timeout);
      unsubscribe();
      resolve();
    });
  });
}

async function main() {
  const args = parseArgs(process.argv);
  const availableTools = normalizeTools(args.tools);

  const client = new CopilotClient();
  if (typeof client.start === "function") {
    await client.start();
  }

  const sessionConfig = {
    model: args.model,
    workingDirectory: args.cwd,
    onPermissionRequest: approveAll,
    ...(Array.isArray(availableTools) ? { availableTools } : {}),
  };

  console.log("[SDK-Probe] sessionConfig", JSON.stringify({
    model: sessionConfig.model,
    workingDirectory: sessionConfig.workingDirectory,
    availableToolsCount: Array.isArray(availableTools) ? availableTools.length : null,
    availableTools,
  }));

  const session = await client.createSession(sessionConfig);

  let text = "";
  let toolStartCount = 0;
  let toolCompleteCount = 0;
  const toolNames = new Set();

  const offDelta = session.on("assistant.message_delta", (event) => {
    const delta = event?.data?.deltaContent;
    if (typeof delta === "string") {
      text += delta;
    }
  });

  const offMessage = session.on("assistant.message", (event) => {
    if (!text && typeof event?.data?.content === "string") {
      text = event.data.content;
    }
  });

  const offToolStart = session.on("tool.execution_start", (event) => {
    toolStartCount += 1;
    const name = event?.data?.toolName ?? event?.data?.mcpToolName;
    if (typeof name === "string" && name.length > 0) {
      toolNames.add(name);
    }
  });

  const offToolComplete = session.on("tool.execution_complete", (event) => {
    toolCompleteCount += 1;
    const name = event?.data?.toolName ?? event?.data?.mcpToolName;
    if (typeof name === "string" && name.length > 0) {
      toolNames.add(name);
    }
  });

  const idle = onceIdle(session);
  await session.send({ prompt: args.prompt, mode: "immediate" });
  await idle;

  offDelta();
  offMessage();
  offToolStart();
  offToolComplete();

  console.log("[SDK-Probe] result", JSON.stringify({
    prompt: args.prompt,
    responsePreview: text.slice(0, 1000),
    toolStartCount,
    toolCompleteCount,
    toolNames: Array.from(toolNames),
  }));

  if (typeof session.destroy === "function") {
    await session.destroy();
  }
  if (typeof client.stop === "function") {
    await client.stop();
  }
}

main().catch(async (error) => {
  console.error("[SDK-Probe] failed", String(error));
  process.exitCode = 1;
});
