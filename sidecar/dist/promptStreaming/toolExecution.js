export function extractToolExecutionResult(event, toolNameByCallID) {
    const toolCallID = event?.data?.toolCallId;
    const toolName = event?.data?.toolName
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
    const detailsRaw = (typeof firstContentText === "string" && firstContentText.length > 0 ? firstContentText : null)
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
    return {
        toolCallID: typeof toolCallID === "string" ? toolCallID : null,
        toolName,
        success: event?.data?.success !== false,
        details: details.length > 0 ? details.slice(0, 280) : undefined,
        detailsChars: details.length,
    };
}
