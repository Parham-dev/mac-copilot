import { CopilotClient, approveAll } from "@github/copilot-sdk";
import { mkdirSync } from "node:fs";

let client = null;
let session = null;
let lastAuthError = null;
let lastAuthAt = null;
let activeModel = "gpt-5";
let activeWorkingDirectory = null;
let activeAvailableTools = null;

function ensureCopilotShellPath() {
  const currentPath = String(process.env.PATH ?? "");
  const currentNodeDirectory = process.execPath
    ? process.execPath.split("/").slice(0, -1).join("/")
    : "";

  const pathSegments = currentPath.split(":").filter((entry) => entry.length > 0);
  const normalized = [];

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
  return session !== null;
}

export async function startClient(token) {
  try {
    process.env.GITHUB_TOKEN = token;
    ensureCopilotShellPath();
    client = new CopilotClient();
    await client.start();
    await createSessionForContext(activeModel, activeWorkingDirectory, activeAvailableTools);
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
  activeAvailableTools = null;
}

export function getCopilotReport() {
  return {
    sessionReady: session !== null,
    activeModel,
    activeWorkingDirectory,
    activeAvailableTools,
    lastAuthAt,
    lastAuthError,
    usingGitHubToken: Boolean(process.env.GITHUB_TOKEN),
  };
}

function normalizeAllowedTools(allowedTools) {
  if (!Array.isArray(allowedTools)) {
    return null;
  }

  const normalized = Array.from(new Set(
    allowedTools
      .filter((entry) => typeof entry === "string")
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0)
  )).sort((lhs, rhs) => lhs.localeCompare(rhs));

  return normalized.length > 0 ? normalized : null;
}

function sameAllowedTools(lhs, rhs) {
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

async function createSessionForContext(model, workingDirectory, allowedTools) {
  if (workingDirectory) {
    mkdirSync(workingDirectory, { recursive: true });
  }

  const normalizedTools = normalizeAllowedTools(allowedTools);

  session = await client.createSession({
    model,
    streaming: true,
    onPermissionRequest: approveAll,
    ...(workingDirectory ? { workingDirectory } : {}),
    ...(normalizedTools ? { availableTools: normalizedTools } : {}),
  });

  activeModel = model;
  activeWorkingDirectory = workingDirectory;
  activeAvailableTools = normalizedTools;
}

async function ensureSessionForContext(model, projectPath, allowedTools) {
  const requested = typeof model === "string" && model.trim().length > 0 ? model.trim() : "gpt-5";
  const requestedWorkingDirectory = typeof projectPath === "string" && projectPath.trim().length > 0
    ? projectPath.trim()
    : null;
  const requestedAvailableTools = normalizeAllowedTools(allowedTools);

  if (
    session
    && activeModel === requested
    && activeWorkingDirectory === requestedWorkingDirectory
    && sameAllowedTools(activeAvailableTools, requestedAvailableTools)
  ) {
    return;
  }

  if (!client) {
    throw new Error("Copilot client is not initialized.");
  }

  await createSessionForContext(requested, requestedWorkingDirectory, requestedAvailableTools);
}

export async function listAvailableModels() {
  if (!client || typeof client.listModels !== "function") {
    return [{
      id: "gpt-5",
      name: "GPT-5",
      capabilities: {
        supports: { vision: false, reasoningEffort: false },
        limits: { max_context_window_tokens: 0 },
      },
    }];
  }

  try {
    const raw = await client.listModels();
    if (!Array.isArray(raw)) {
      return [{
        id: "gpt-5",
        name: "GPT-5",
        capabilities: {
          supports: { vision: false, reasoningEffort: false },
          limits: { max_context_window_tokens: 0 },
        },
      }];
    }

    const models = raw
      .map((item) => {
        if (typeof item === "string") {
          return {
            id: item,
            name: item,
            capabilities: {
              supports: { vision: false, reasoningEffort: false },
              limits: { max_context_window_tokens: 0 },
            },
          };
        }
        if (item && typeof item === "object") {
          const id = typeof item.id === "string"
            ? item.id
            : (typeof item.model === "string" ? item.model : null);

          if (!id) return null;

          const supports = item.capabilities?.supports;
          const limits = item.capabilities?.limits;
          const policy = item.policy;
          const billing = item.billing;

          return {
            id,
            name: typeof item.name === "string" && item.name.length > 0 ? item.name : id,
            capabilities: {
              supports: {
                vision: Boolean(supports?.vision),
                reasoningEffort: Boolean(supports?.reasoningEffort),
              },
              limits: {
                ...(typeof limits?.max_prompt_tokens === "number" ? { max_prompt_tokens: limits.max_prompt_tokens } : {}),
                max_context_window_tokens: typeof limits?.max_context_window_tokens === "number"
                  ? limits.max_context_window_tokens
                  : 0,
              },
            },
            ...(policy && typeof policy === "object"
              ? {
                  policy: {
                    state: typeof policy.state === "string" ? policy.state : "unconfigured",
                    terms: typeof policy.terms === "string" ? policy.terms : "",
                  },
                }
              : {}),
            ...(billing && typeof billing === "object" && typeof billing.multiplier === "number"
              ? { billing: { multiplier: billing.multiplier } }
              : {}),
            ...(typeof item.defaultReasoningEffort === "string"
              ? { defaultReasoningEffort: item.defaultReasoningEffort }
              : {}),
            ...(Array.isArray(item.supportedReasoningEfforts)
              ? {
                  supportedReasoningEfforts: item.supportedReasoningEfforts
                    .filter((entry) => typeof entry === "string" && entry.length > 0),
                }
              : {}),
          };
        }
        return null;
      })
      .filter((value) => value && typeof value.id === "string" && value.id.length > 0);

    const uniqueByID = Array.from(new Map(models.map((model) => [model.id, model])).values());
    return uniqueByID.length > 0
      ? uniqueByID
      : [{
          id: "gpt-5",
          name: "GPT-5",
          capabilities: {
            supports: { vision: false, reasoningEffort: false },
            limits: { max_context_window_tokens: 0 },
          },
        }];
  } catch {
    return [{
      id: "gpt-5",
      name: "GPT-5",
      capabilities: {
        supports: { vision: false, reasoningEffort: false },
        limits: { max_context_window_tokens: 0 },
      },
    }];
  }
}

export async function sendPrompt(prompt, model, projectPath, allowedTools, onEvent) {
  if (!session) {
    onEvent({ type: "text", text: "Not authenticated yet. Please complete GitHub auth first." });
    return;
  }

  const trimmedPrompt = String(prompt ?? "").trim();
  if (!trimmedPrompt) {
    onEvent({ type: "text", text: "Please enter a prompt." });
    return;
  }

  await ensureSessionForContext(model, projectPath, allowedTools);

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

  const toolNameByCallID = new Map();

  onEvent({ type: "status", label: "Analyzing request" });

  const unsubscribeTurnStart = session.on("assistant.turn_start", () => {
    onEvent({ type: "status", label: "Generating response" });
  });

  const unsubscribeDelta = session.on("assistant.message_delta", (event) => {
    const delta = event?.data?.deltaContent;
    if (typeof delta === "string" && delta.length > 0) {
      sawAnyOutput = true;
      sawDeltaOutput = true;
      onEvent({ type: "text", text: delta });
    }
  });

  const unsubscribeFinal = session.on("assistant.message", (event) => {
    const content = event?.data?.content;
    if (!sawDeltaOutput && typeof content === "string" && content.length > 0) {
      sawAnyOutput = true;
      onEvent({ type: "text", text: content });
    }
  });

  const unsubscribeToolStart = session.on("tool.execution_start", (event) => {
    const toolCallID = event?.data?.toolCallId;
    const toolName = event?.data?.toolName ?? event?.data?.mcpToolName ?? "Tool";

    if (typeof toolCallID === "string" && toolCallID.length > 0) {
      toolNameByCallID.set(toolCallID, toolName);
    }

    onEvent({
      type: "tool_start",
      toolName,
    });
  });

  const unsubscribeToolComplete = session.on("tool.execution_complete", (event) => {
    const toolCallID = event?.data?.toolCallId;
    const toolName =
      event?.data?.toolName
      ?? (typeof toolCallID === "string" ? toolNameByCallID.get(toolCallID) : null)
      ?? "Tool";

    if (typeof toolCallID === "string" && toolCallID.length > 0) {
      toolNameByCallID.delete(toolCallID);
    }

    const resultContents = event?.data?.result?.contents;
    const firstContentText = Array.isArray(resultContents)
      ? resultContents
          .map((item) => {
            if (item?.type === "text" && typeof item.text === "string") {
              return item.text;
            }
            if (item?.type === "terminal" && typeof item.text === "string") {
              return item.text;
            }
            return null;
          })
          .find((value) => typeof value === "string" && value.trim().length > 0)
      : null;

    const resultContent = event?.data?.result?.content;
    const errorMessage = event?.data?.error?.message;
    const detailsRaw =
      (typeof firstContentText === "string" && firstContentText.length > 0 ? firstContentText : null)
      ?? (typeof resultContent === "string" && resultContent.length > 0 ? resultContent : null)
      ?? (typeof errorMessage === "string" && errorMessage.length > 0 ? errorMessage : null);

    let details = typeof detailsRaw === "string" ? detailsRaw : "";
    details = details
      .replace(/\n+/g, " ")
      .replace(/^\s*\d+\s*/, "")
      .replace(/<?exited?\s+with\s+exit\s*code\s*\d+>?/gi, "")
      .trim();

    if (!details && event?.data?.success !== false) {
      details = "Command completed successfully.";
    }

    onEvent({
      type: "tool_complete",
      toolName,
      success: event?.data?.success !== false,
      details: details.length > 0 ? details.slice(0, 280) : undefined,
    });
  });

  const unsubscribeIdle = session.on("session.idle", () => {
    onEvent({ type: "done" });
    resolveDone();
  });

  try {
    await session.send({ prompt: trimmedPrompt, mode: "immediate" });
    await done;

    if (!sawAnyOutput) {
      onEvent({ type: "text", text: "Copilot returned no text output for this request." });
    }
  } finally {
    clearTimeout(timeoutId);
    unsubscribeTurnStart();
    unsubscribeDelta();
    unsubscribeFinal();
    unsubscribeToolStart();
    unsubscribeToolComplete();
    unsubscribeIdle();
  }
}
