import SwiftUI

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let statusChipsByMessageID: [UUID: [String]]
    let toolExecutionsByMessageID: [UUID: [ChatMessage.ToolExecution]]
    let streamingAssistantMessageID: UUID?

    @State private var hasScrolledInitially = false
    @State private var pendingScrollRequestID = 0

    private let bottomAnchorID = "chat-transcript-bottom-anchor"

    private var latestMessageCharacterCount: Int {
        messages.last?.text.count ?? 0
    }

    private var scrollUpdateToken: Int {
        var hasher = Hasher()
        hasher.combine(messages.count)
        hasher.combine(messages.last?.id)
        hasher.combine(latestMessageCharacterCount)
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
            .onDisappear {
                pendingScrollRequestID += 1
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
        DispatchQueue.main.async {
            scrollToBottom(using: proxy, animated: false)
        }
    }

    private func scheduleScrollToBottom(using proxy: ScrollViewProxy) {
        pendingScrollRequestID += 1
        let requestID = pendingScrollRequestID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            guard requestID == pendingScrollRequestID else { return }
            scrollToBottom(using: proxy, animated: false)
        }
    }
}
