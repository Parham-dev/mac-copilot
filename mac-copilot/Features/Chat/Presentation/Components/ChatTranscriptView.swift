import SwiftUI

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let statusChipsByMessageID: [UUID: [String]]
    let toolExecutionsByMessageID: [UUID: [ChatMessage.ToolExecution]]
    let streamingAssistantMessageID: UUID?

    @State private var hasScrolledInitially = false

    private let bottomAnchorID = "chat-transcript-bottom-anchor"

    private var scrollUpdateToken: Int {
        var hasher = Hasher()
        hasher.combine(messages.count)
        hasher.combine(messages.reduce(0) { $0 + $1.text.count })
        hasher.combine(statusChipsByMessageID.values.reduce(0) { $0 + $1.count })
        hasher.combine(toolExecutionsByMessageID.values.reduce(0) { $0 + $1.count })
        hasher.combine(streamingAssistantMessageID)
        return hasher.finalize()
    }

    var body: some View {
        ScrollViewReader { proxy in
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

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)
            }
            .onChange(of: scrollUpdateToken) { _, _ in
                if !hasScrolledInitially {
                    performInitialScrollIfNeeded(using: proxy)
                    return
                }

                scheduleScrollToBottom(using: proxy)
            }
            .onAppear {
                performInitialScrollIfNeeded(using: proxy)
            }
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.2), action)
        } else {
            action()
        }
    }

    private func performInitialScrollIfNeeded(using proxy: ScrollViewProxy) {
        guard !hasScrolledInitially else { return }
        guard !messages.isEmpty else { return }

        hasScrolledInitially = true

        scrollToBottom(using: proxy, animated: false)

        DispatchQueue.main.async {
            scrollToBottom(using: proxy, animated: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            scrollToBottom(using: proxy, animated: false)
        }
    }

    private func scheduleScrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            let shouldAnimate = false
            scrollToBottom(using: proxy, animated: shouldAnimate)
        }
    }
}
