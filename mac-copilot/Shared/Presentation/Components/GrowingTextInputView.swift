import SwiftUI
import AppKit

private extension NSFont {
    var copilotForgeLineHeight: CGFloat {
        ascender - descender + leading
    }
}

struct GrowingTextInputView: View {
    @Binding var text: String
    let placeholder: String
    let minLines: Int
    let maxLines: Int
    let isEditable: Bool
    let onShiftEnter: (() -> Void)?
    let showsTextMetrics: Bool
    let validationMessageProvider: ((String) -> String?)?

    @State private var dynamicHeight: CGFloat

    init(
        text: Binding<String>,
        placeholder: String,
        minLines: Int = 2,
        maxLines: Int = 8,
        isEditable: Bool = true,
        onShiftEnter: (() -> Void)? = nil,
        showsTextMetrics: Bool = false,
        validationMessageProvider: ((String) -> String?)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.minLines = max(1, minLines)
        self.maxLines = max(maxLines, minLines)
        self.isEditable = isEditable
        self.onShiftEnter = onShiftEnter
        self.showsTextMetrics = showsTextMetrics
        self.validationMessageProvider = validationMessageProvider

        let initialHeight = Self.heightForLineCount(self.minLines)
        self._dynamicHeight = State(initialValue: initialHeight)
    }

    private var minHeight: CGFloat {
        Self.heightForLineCount(minLines)
    }

    private var maxHeight: CGFloat {
        Self.heightForLineCount(maxLines)
    }

    private var validationMessage: String? {
        validationMessageProvider?(text)
    }

    private var characterCount: Int {
        text.count
    }

    private var estimatedTokenCount: Int {
        guard characterCount > 0 else { return 0 }
        return Int(ceil(Double(characterCount) / 4.0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                GrowingTextEditorRepresentable(
                    text: $text,
                    dynamicHeight: $dynamicHeight,
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                    isEditable: isEditable,
                    onShiftEnter: onShiftEnter
                )
                .frame(height: dynamicHeight)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((validationMessage == nil ? Color.secondary.opacity(0.25) : Color.red.opacity(0.8)), lineWidth: 1)
            )

            HStack {
                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 8)

                if showsTextMetrics {
                    Text("\(characterCount) chars • ~\(estimatedTokenCount) tokens")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static func heightForLineCount(_ lines: Int) -> CGFloat {
        let lineHeight = NSFont.preferredFont(forTextStyle: .body).copilotForgeLineHeight
        return ceil((lineHeight * CGFloat(lines)) + 14)
    }
}

private struct GrowingTextEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat

    let minHeight: CGFloat
    let maxHeight: CGFloat
    let isEditable: Bool
    let onShiftEnter: (() -> Void)?

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
        context.coordinator.stageTextValue(textView.string)

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? SubmitAwareTextView else { return }

        context.coordinator.updateParent(self)
        textView.onShiftEnter = onShiftEnter
        textView.isEditable = isEditable

        if context.coordinator.shouldDeferBindingToTextViewSync(boundText: text) {
            return
        }

        if textView.string != text {
            textView.string = text
            context.coordinator.stageTextValue(textView.string)
            context.coordinator.scheduleMetricsRefresh(for: textView)
            context.coordinator.enqueueBindingFlush()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var parent: GrowingTextEditorRepresentable
        private var pendingBindingFlush = false
        private var pendingMetricsRefresh = false
        private var pendingScrollerRefresh = false
        private var latestPendingTextValue = ""
        private var latestPendingHeightValue: CGFloat = 0
        private var latestShouldShowScroller = false

        init(parent: GrowingTextEditorRepresentable) {
            self.parent = parent
        }

        func updateParent(_ parent: GrowingTextEditorRepresentable) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            stageTextValue(textView.string)
            scheduleMetricsRefresh(for: textView)
            enqueueBindingFlush()
        }

        func stageTextValue(_ value: String) {
            latestPendingTextValue = value
        }

        func shouldDeferBindingToTextViewSync(boundText: String) -> Bool {
            pendingBindingFlush && boundText != latestPendingTextValue
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
                latestShouldShowScroller = contentHeight > maxHeight
                scheduleScrollerRefresh(for: scrollView)
            }
        }

        func scheduleMetricsRefresh(for textView: NSTextView) {
            guard !pendingMetricsRefresh else { return }
            pendingMetricsRefresh = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self, weak textView] in
                guard let self else { return }
                self.pendingMetricsRefresh = false
                guard let textView else { return }
                self.updateHeight(for: textView)
                self.enqueueBindingFlush()
            }
        }

        private func scheduleScrollerRefresh(for scrollView: NSScrollView) {
            guard !pendingScrollerRefresh else { return }
            pendingScrollerRefresh = true

            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self else { return }
                self.pendingScrollerRefresh = false
                guard let scrollView else { return }

                let shouldShowScroller = self.latestShouldShowScroller
                if scrollView.hasVerticalScroller != shouldShowScroller {
                    scrollView.hasVerticalScroller = shouldShowScroller
                }
            }
        }

        private func enqueueHeightBindingUpdate(_ newValue: CGFloat) {
            latestPendingHeightValue = newValue
        }

        func enqueueBindingFlush() {
            guard !pendingBindingFlush else { return }
            pendingBindingFlush = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingBindingFlush = false

                let text = self.latestPendingTextValue
                if self.parent.text != text {
                    self.parent.text = text
                }

                let rounded = (self.latestPendingHeightValue * 2).rounded() / 2
                if abs(self.parent.dynamicHeight - rounded) > 1.0 {
                    self.parent.dynamicHeight = rounded
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
