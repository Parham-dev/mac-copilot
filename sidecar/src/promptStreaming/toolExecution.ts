export function extractToolExecutionResult(event: any, toolNameByCallID: Map<string, string>) {
  const success = event?.data?.success !== false;
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
  const errorMessage =
    event?.data?.error?.message
    ?? (typeof event?.data?.error === "string" ? event.data.error : null)
    ?? (typeof event?.error === "string" ? event.error : null)
    ?? event?.error?.message
    ?? (typeof event?.data?.reason === "string" ? event.data.reason : null);
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

  if (!details && success) {
    details = "Command completed successfully.";
  }

  if (!details && !success) {
    details = "Tool execution failed without an error payload.";
  }

  return {
    toolCallID: typeof toolCallID === "string" ? toolCallID : null,
    toolName,
    success,
    details: details.length > 0 ? details.slice(0, 280) : undefined,
    detailsChars: details.length,
  };
}
