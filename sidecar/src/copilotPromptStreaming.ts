type PromptEvent = Record<string, unknown>;

export async function streamPromptWithSession(
  session: any,
  prompt: string,
  onEvent: (event: PromptEvent) => void
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

  onEvent({ type: "status", label: "Analyzing request" });

  const unsubscribeTurnStart = session.on("assistant.turn_start", () => {
    onEvent({ type: "status", label: "Generating response" });
  });

  const unsubscribeDelta = session.on("assistant.message_delta", (event: any) => {
    const delta = event?.data?.deltaContent;
    if (typeof delta === "string" && delta.length > 0) {
      sawAnyOutput = true;
      sawDeltaOutput = true;
      onEvent({ type: "text", text: delta });
    }
  });

  const unsubscribeFinal = session.on("assistant.message", (event: any) => {
    const content = event?.data?.content;
    if (!sawDeltaOutput && typeof content === "string" && content.length > 0) {
      sawAnyOutput = true;
      onEvent({ type: "text", text: content });
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
          .map((item: any) => {
            if (item?.type === "text" && typeof item.text === "string") {
              return item.text;
            }
            if (item?.type === "terminal" && typeof item.text === "string") {
              return item.text;
            }
            return null;
          })
          .find((value: unknown) => typeof value === "string" && value.trim().length > 0)
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
