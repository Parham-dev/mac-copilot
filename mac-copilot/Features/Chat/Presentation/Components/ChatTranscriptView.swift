import SwiftUI

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let statusChipsByMessageID: [UUID: [String]]
    let toolExecutionsByMessageID: [UUID: [ChatMessage.ToolExecution]]
    let streamingAssistantMessageID: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    ChatMessageRow(
                        message: message,
                        statusChips: statusChipsByMessageID[message.id] ?? [],
                        toolExecutions: toolExecutionsByMessageID[message.id] ?? [],
                        isStreaming: streamingAssistantMessageID == message.id
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 6)
        }
    }
}
