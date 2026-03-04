import Foundation

enum PromptSSEEventMapper {
    static func events(from payload: PromptSSEPayload) -> [PromptStreamEvent] {
        guard let kind = payload.type else {
            return []
        }

        switch kind {
        case "status":
            if let label = payload.label, !label.isEmpty {
                return [.status(label)]
            }
            return []
        case "tool_start":
            if let name = payload.toolName, !name.isEmpty {
                return [.status("Tool started: \(name)")]
            }
            return []
        case "tool_complete":
            if let name = payload.toolName, !name.isEmpty {
                let suffix = (payload.success == false) ? "failed" : "done"
                return [
                    .status("Tool \(suffix): \(name)"),
                    .toolExecution(
                        PromptToolExecutionEvent(
                            toolName: name,
                            success: payload.success != false,
                            details: payload.details,
                            input: payload.toolInput,
                            output: payload.toolOutput ?? payload.details
                        )
                    ),
                ]
            }
            return []
        case "done":
            return [.completed]
        case "usage":
            return [
                .usage(
                    PromptUsageEvent(
                        inputTokens: payload.inputTokens,
                        outputTokens: payload.outputTokens,
                        totalTokens: payload.totalTokens,
                        cacheReadTokens: payload.cacheReadTokens,
                        cacheWriteTokens: payload.cacheWriteTokens,
                        cost: payload.cost,
                        durationMs: payload.duration,
                        model: payload.model,
                        raw: payload.raw
                    )
                )
            ]
        default:
            return []
        }
    }
}
