import Foundation

extension ChatViewModel {
    func hydrateMetadata(from messages: [ChatMessage]) {
        var chipsMap: [UUID: [String]] = [:]
        var toolsMap: [UUID: [ChatMessage.ToolExecution]] = [:]
        var segmentsMap: [UUID: [AssistantTranscriptSegment]] = [:]

        for message in messages where message.role == .assistant {
            guard let metadata = message.metadata else { continue }

            if !metadata.statusChips.isEmpty {
                chipsMap[message.id] = metadata.statusChips
            }

            if !metadata.toolExecutions.isEmpty {
                toolsMap[message.id] = metadata.toolExecutions
            }

            if !metadata.transcriptSegments.isEmpty {
                segmentsMap[message.id] = metadata.transcriptSegments
            }
        }

        statusChipsByMessageID = chipsMap
        toolExecutionsByMessageID = toolsMap
        inlineSegmentsByMessageID = segmentsMap
    }

    func appendStatus(_ label: String, for messageID: UUID) {
        let current = statusChipsByMessageID[messageID] ?? []
        guard current.last != label else { return }
        statusChipsByMessageID[messageID] = current + [label]
    }

    @discardableResult
    func appendToolExecution(_ event: PromptToolExecutionEvent, for messageID: UUID) -> ChatMessage.ToolExecution {
        let current = toolExecutionsByMessageID[messageID] ?? []
        let entry = ChatMessage.ToolExecution(
            toolName: event.toolName,
            success: event.success,
            details: event.details,
            input: event.input,
            output: event.output
        )
        toolExecutionsByMessageID[messageID] = current + [entry]
        return entry
    }

    func metadata(for messageID: UUID) -> ChatMessage.Metadata? {
        let chips = statusChipsByMessageID[messageID] ?? []
        let tools = toolExecutionsByMessageID[messageID] ?? []
        let segments = inlineSegmentsByMessageID[messageID] ?? []
        guard !chips.isEmpty || !tools.isEmpty || !segments.isEmpty else {
            return nil
        }

        return ChatMessage.Metadata(statusChips: chips, toolExecutions: tools, transcriptSegments: segments)
    }
}
