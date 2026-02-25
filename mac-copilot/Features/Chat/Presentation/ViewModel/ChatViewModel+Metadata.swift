import Foundation

extension ChatViewModel {
    func hydrateMetadata(from messages: [ChatMessage]) {
        var chipsMap: [UUID: [String]] = [:]
        var toolsMap: [UUID: [ChatMessage.ToolExecution]] = [:]

        for message in messages where message.role == .assistant {
            guard let metadata = message.metadata else { continue }

            if !metadata.statusChips.isEmpty {
                chipsMap[message.id] = metadata.statusChips
            }

            if !metadata.toolExecutions.isEmpty {
                toolsMap[message.id] = metadata.toolExecutions
            }
        }

        statusChipsByMessageID = chipsMap
        toolExecutionsByMessageID = toolsMap
    }

    func appendStatus(_ label: String, for messageID: UUID) {
        let current = statusChipsByMessageID[messageID] ?? []
        guard current.last != label else { return }
        statusChipsByMessageID[messageID] = current + [label]
    }

    func appendToolExecution(_ event: PromptToolExecutionEvent, for messageID: UUID) {
        let current = toolExecutionsByMessageID[messageID] ?? []
        let entry = ChatMessage.ToolExecution(
            toolName: event.toolName,
            success: event.success,
            details: event.details
        )
        toolExecutionsByMessageID[messageID] = current + [entry]
    }

    func metadata(for messageID: UUID) -> ChatMessage.Metadata? {
        let chips = statusChipsByMessageID[messageID] ?? []
        let tools = toolExecutionsByMessageID[messageID] ?? []
        guard !chips.isEmpty || !tools.isEmpty else {
            return nil
        }

        return ChatMessage.Metadata(statusChips: chips, toolExecutions: tools)
    }
}
