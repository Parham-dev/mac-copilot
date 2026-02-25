import SwiftUI
import AppKit

private extension NSFont {
    var composerLineHeight: CGFloat {
        ascender - descender + leading
    }
}

struct ChatComposerView: View {
    @Binding var draftPrompt: String
    @Binding var selectedModel: String
    let availableModels: [String]
    let selectedModelInfoLabel: String
    let isSending: Bool
    let onSend: () -> Void

    @State private var composerHeight: CGFloat = 56

    private var canSend: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private var minComposerHeight: CGFloat {
        let lineHeight = NSFont.preferredFont(forTextStyle: .body).composerLineHeight
        return ceil((lineHeight * 2) + 14)
    }

    private var maxComposerHeight: CGFloat {
        let lineHeight = NSFont.preferredFont(forTextStyle: .body).composerLineHeight
        return ceil((lineHeight * 8) + 14)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if draftPrompt.isEmpty {
                        Text("Ask CopilotForge to build something…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }

                    ComposerTextView(
                        text: $draftPrompt,
                        dynamicHeight: $composerHeight,
                        minHeight: minComposerHeight,
                        maxHeight: maxComposerHeight,
                        isEditable: !isSending,
                        onShiftEnter: {
                            guard canSend else { return }
                            onSend()
                        }
                    )
                    .frame(height: composerHeight)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )

                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .disabled(!canSend)
            }

            HStack {
                ChatToolbarControlsView(
                    selectedModel: $selectedModel,
                    availableModels: availableModels,
                    selectedModelInfoLabel: selectedModelInfoLabel
                )
                Spacer()
                Text(isSending ? "Generating…" : "Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat

    let minHeight: CGFloat
    let maxHeight: CGFloat
    let isEditable: Bool
    let onShiftEnter: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = SubmitAwareTextView()
        textView.delegate = context.coordinator
        textView.onShiftEnter = onShiftEnter
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = true
        textView.textContainerInset = NSSize(width: 8, height: 7)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.string = text
        textView.isEditable = isEditable

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        scrollView.documentView = textView
        context.coordinator.updateScrollerOnly(for: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? SubmitAwareTextView else { return }

        textView.onShiftEnter = onShiftEnter
        textView.isEditable = isEditable

        if textView.string != text {
            textView.string = text
            context.coordinator.updateScrollerOnly(for: textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: ComposerTextView
        private var pendingTextUpdate = false
        private var latestPendingTextValue = ""
        private var pendingHeightUpdate = false
        private var latestPendingHeightValue: CGFloat = 0
        private let composerDebugEnabled = true

        init(parent: ComposerTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            enqueueTextBindingUpdate(textView.string)
            updateHeight(for: textView)
        }

        private func enqueueTextBindingUpdate(_ newValue: String) {
            latestPendingTextValue = newValue
            guard !pendingTextUpdate else { return }
            pendingTextUpdate = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingTextUpdate = false
                let value = self.latestPendingTextValue
                if self.parent.text != value {
                    self.parent.text = value
                }
            }
        }

        func updateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let contentHeight = layoutManager.usedRect(for: textContainer).height + (textView.textContainerInset.height * 2)
            let clamped = min(max(contentHeight, parent.minHeight), parent.maxHeight)
            let maxHeight = self.parent.maxHeight

            enqueueHeightBindingUpdate(clamped)

            if let scrollView = textView.enclosingScrollView {
                let shouldShowScroller = contentHeight > maxHeight
                if scrollView.hasVerticalScroller != shouldShowScroller {
                    scrollView.hasVerticalScroller = shouldShowScroller
                }
            }
        }

        private func enqueueHeightBindingUpdate(_ newValue: CGFloat) {
            latestPendingHeightValue = newValue
            guard !pendingHeightUpdate else { return }
            pendingHeightUpdate = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingHeightUpdate = false

                let rounded = (self.latestPendingHeightValue * 2).rounded() / 2
                if abs(self.parent.dynamicHeight - rounded) > 0.25 {
                    if self.composerDebugEnabled {
                        NSLog("[CopilotForge][Composer] apply dynamicHeight=%.1f", rounded)
                    }
                    self.parent.dynamicHeight = rounded
                }
            }
        }

        func updateScrollerOnly(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let contentHeight = layoutManager.usedRect(for: textContainer).height + (textView.textContainerInset.height * 2)
            let maxHeight = self.parent.maxHeight

            if let scrollView = textView.enclosingScrollView {
                let shouldShowScroller = contentHeight > maxHeight
                if scrollView.hasVerticalScroller != shouldShowScroller {
                    scrollView.hasVerticalScroller = shouldShowScroller
                }
            }
        }
    }
}

private final class SubmitAwareTextView: NSTextView {
    var onShiftEnter: (() -> Void)?

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)),
           NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            onShiftEnter?()
            return
        }

        super.doCommand(by: selector)
    }
}
