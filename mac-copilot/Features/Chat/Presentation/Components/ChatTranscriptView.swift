import SwiftUI

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let inlineSegmentsByMessageID: [UUID: [AssistantTranscriptSegment]]
    let streamingAssistantMessageID: UUID?

    @State private var hasScrolledInitially = false

    private let bottomAnchorID = "chat-transcript-bottom-anchor"

    private var scrollUpdateToken: Int {
        var hasher = Hasher()
        hasher.combine(messages.count)
        hasher.combine(messages.last?.id)
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
                            isStreaming: streamingAssistantMessageID == message.id,
                            inlineSegments: inlineSegmentsByMessageID[message.id] ?? []
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
        Task { @MainActor in
            await Task.yield()
            scrollToBottom(using: proxy, animated: false)
        }
    }

    private func scheduleScrollToBottom(using proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            scrollToBottom(using: proxy, animated: false)
        }
    }
}
