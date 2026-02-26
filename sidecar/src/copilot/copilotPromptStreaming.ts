import { ProtocolMarkupFilter, protocolMarkerPattern } from "../promptStreaming/protocolMarkup.js";
import { extractToolExecutionResult } from "../promptStreaming/toolExecution.js";

type PromptEvent = Record<string, unknown>;

const promptTraceEnabled = process.env.COPILOTFORGE_PROMPT_TRACE === "1";

export async function streamPromptWithSession(
  session: any,
  prompt: string,
  onEvent: (event: PromptEvent) => void,
  debugLabel?: string
) {
  const trimmedPrompt = String(prompt ?? "").trim();
  if (!trimmedPrompt) {
    onEvent({ type: "text", text: "Please enter a prompt." });
    return;
  }

  let sawAnyOutput = false;
  let sawDeltaOutput = false;

  let resolveDone: () => void;
  let rejectDone: (reason?: unknown) => void;
  const done = new Promise<void>((resolve, reject) => {
    resolveDone = resolve;
    rejectDone = reject;
  });

  const timeoutMs = 120000;
  const timeoutId = setTimeout(() => {
    rejectDone(new Error(`Copilot response timed out after ${timeoutMs}ms`));
  }, timeoutMs);

  const toolNameByCallID = new Map<string, string>();
  const protocolFilter = new ProtocolMarkupFilter();
  const traceID = debugLabel?.trim().length ? debugLabel.trim() : `session-${Date.now().toString(36)}`;

  const logTrace = (message: string, extras?: Record<string, unknown>) => {
    if (!promptTraceEnabled) {
      return;
    }

    if (extras) {
      console.log(`[CopilotForge][PromptTrace][${traceID}] ${message}`, JSON.stringify(extras));
      return;
    }

    console.log(`[CopilotForge][PromptTrace][${traceID}] ${message}`);
  };

  onEvent({ type: "status", label: "Analyzing request" });

  const unsubscribeTurnStart = session.on("assistant.turn_start", () => {
    onEvent({ type: "status", label: "Generating response" });
  });

  const unsubscribeDelta = session.on("assistant.message_delta", (event: any) => {
    const delta = event?.data?.deltaContent;
    if (typeof delta === "string" && delta.length > 0) {
      const filtered = protocolFilter.process(delta);

      if (promptTraceEnabled) {
        const rawHasProtocolMarkup = protocolMarkerPattern.test(delta);
        const filteredHasProtocolMarkup = protocolMarkerPattern.test(filtered);

        if (rawHasProtocolMarkup || filteredHasProtocolMarkup) {
          logTrace("delta protocol marker observation", {
            rawLength: delta.length,
            filteredLength: filtered.length,
            rawHasProtocolMarkup,
            filteredHasProtocolMarkup,
            rawPreview: delta.slice(0, 160),
            filteredPreview: filtered.slice(0, 160),
          });
        }
      }

      if (filtered.length > 0) {
        sawAnyOutput = true;
        sawDeltaOutput = true;
        onEvent({ type: "text", text: filtered });
      }
    }
  });

  const unsubscribeFinal = session.on("assistant.message", (event: any) => {
    const content = event?.data?.content;
    if (!sawDeltaOutput && typeof content === "string" && content.length > 0) {
      const filtered = protocolFilter.process(content) + protocolFilter.flush();

      if (promptTraceEnabled) {
        const rawHasProtocolMarkup = protocolMarkerPattern.test(content);
        const filteredHasProtocolMarkup = protocolMarkerPattern.test(filtered);

        if (rawHasProtocolMarkup || filteredHasProtocolMarkup) {
          logTrace("final message protocol marker observation", {
            rawLength: content.length,
            filteredLength: filtered.length,
            rawHasProtocolMarkup,
            filteredHasProtocolMarkup,
            rawPreview: content.slice(0, 200),
            filteredPreview: filtered.slice(0, 200),
          });
        }
      }

      if (filtered.length > 0) {
        sawAnyOutput = true;
        onEvent({ type: "text", text: filtered });
      }
    }
  });

  const unsubscribeToolStart = session.on("tool.execution_start", (event: any) => {
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

  const unsubscribeToolComplete = session.on("tool.execution_complete", (event: any) => {
    const { toolName, success, details } = extractToolExecutionResult(event, toolNameByCallID);

    onEvent({
      type: "tool_complete",
      toolName,
      success,
      details,
    });
  });

  const unsubscribeIdle = session.on("session.idle", () => {
    onEvent({ type: "done" });
    resolveDone();
  });

  try {
    await session.send({ prompt: trimmedPrompt, mode: "immediate" });
    await done;

    const remaining = protocolFilter.flush();
    if (promptTraceEnabled) {
      const remainingHasProtocolMarkup = protocolMarkerPattern.test(remaining);
      if (remainingHasProtocolMarkup) {
        logTrace("flush emitted protocol-like marker", {
          remainingLength: remaining.length,
          preview: remaining.slice(0, 200),
        });
      }
    }

    if (remaining.length > 0) {
      sawAnyOutput = true;
      onEvent({ type: "text", text: remaining });
    }

    if (!sawAnyOutput) {
      onEvent({ type: "text", text: "Copilot returned no text output for this request." });
    }
  } finally {
    logTrace("stream finished", { sawAnyOutput, sawDeltaOutput });
    clearTimeout(timeoutId);
    unsubscribeTurnStart();
    unsubscribeDelta();
    unsubscribeFinal();
    unsubscribeToolStart();
    unsubscribeToolComplete();
    unsubscribeIdle();
  }
}
