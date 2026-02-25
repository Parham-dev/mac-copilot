import SwiftUI

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let statusChipsByMessageID: [UUID: [String]]
    let toolExecutionsByMessageID: [UUID: [ChatMessage.ToolExecution]]
    let streamingAssistantMessageID: UUID?

    @State private var contentBottom: CGFloat = 0
    @State private var viewportBottom: CGFloat = 0
    @State private var autoScrollEnabled = true
    @State private var hasScrolledInitially = false

    private let bottomAnchorID = "chat-transcript-bottom-anchor"

    private var distanceFromBottom: CGFloat {
        max(contentBottom - viewportBottom, 0)
    }

    private var isNearBottom: Bool {
        distanceFromBottom <= 56
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
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: ChatContentBottomPreferenceKey.self,
                                        value: geometry.frame(in: .named("ChatTranscriptScroll")).maxY
                                    )
                            }
                        )
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)
            }
            .coordinateSpace(name: "ChatTranscriptScroll")
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ChatViewportBottomPreferenceKey.self,
                            value: geometry.frame(in: .named("ChatTranscriptScroll")).maxY
                        )
                }
            )
            .onPreferenceChange(ChatContentBottomPreferenceKey.self) { value in
                contentBottom = value
                updateAutoScrollState()
                performInitialScrollIfNeeded(using: proxy)
            }
            .onPreferenceChange(ChatViewportBottomPreferenceKey.self) { value in
                viewportBottom = value
                updateAutoScrollState()
                performInitialScrollIfNeeded(using: proxy)
            }
            .onChange(of: messages) { _ in
                if !hasScrolledInitially {
                    performInitialScrollIfNeeded(using: proxy)
                    return
                }

                guard autoScrollEnabled else { return }
                scrollToBottom(using: proxy)
            }
            .onChange(of: statusChipsByMessageID) { _ in
                guard autoScrollEnabled else { return }
                scrollToBottom(using: proxy)
            }
            .onChange(of: toolExecutionsByMessageID) { _ in
                guard autoScrollEnabled else { return }
                scrollToBottom(using: proxy)
            }
            .onChange(of: streamingAssistantMessageID) { _ in
                guard autoScrollEnabled else { return }
                scrollToBottom(using: proxy)
            }
            .onAppear {
                performInitialScrollIfNeeded(using: proxy)
            }
        }
    }

    private func updateAutoScrollState() {
        if isNearBottom {
            autoScrollEnabled = true
            return
        }

        if distanceFromBottom > 140 {
            autoScrollEnabled = false
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
        autoScrollEnabled = true

        scrollToBottom(using: proxy, animated: false)

        DispatchQueue.main.async {
            scrollToBottom(using: proxy, animated: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            scrollToBottom(using: proxy, animated: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            scrollToBottom(using: proxy, animated: false)
        }
    }
}

private struct ChatContentBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ChatViewportBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
