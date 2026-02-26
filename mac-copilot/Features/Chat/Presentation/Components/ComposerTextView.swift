import SwiftUI
import AppKit

struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isTextEmpty: Bool
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
        context.coordinator.stageTextValue(textView.string)
        context.coordinator.updateEmptyState(textView.string)

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
            context.coordinator.updateEmptyState(textView.string)
            context.coordinator.scheduleMetricsRefresh(for: textView)
            context.coordinator.enqueueBindingFlush()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var parent: ComposerTextView
        private var pendingBindingFlush = false
        private var pendingMetricsRefresh = false
        private var latestPendingTextValue = ""
        private var latestPendingEmptyState = true
        private var latestPendingHeightValue: CGFloat = 0

        init(parent: ComposerTextView) {
            self.parent = parent
        }

        func updateParent(_ parent: ComposerTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            stageTextValue(textView.string)
            updateEmptyState(textView.string)
            scheduleMetricsRefresh(for: textView)
            enqueueBindingFlush()
        }

        func stageTextValue(_ value: String) {
            latestPendingTextValue = value
            latestPendingEmptyState = value.isEmpty
        }

        func updateEmptyState(_ value: String) {
            latestPendingEmptyState = value.isEmpty
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
                let shouldShowScroller = contentHeight > maxHeight
                if scrollView.hasVerticalScroller != shouldShowScroller {
                    scrollView.hasVerticalScroller = shouldShowScroller
                }
            }
        }

        func scheduleMetricsRefresh(for textView: NSTextView) {
            guard !pendingMetricsRefresh else { return }
            pendingMetricsRefresh = true

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self else { return }
                self.pendingMetricsRefresh = false
                guard let textView else { return }
                self.updateHeight(for: textView)
                self.enqueueBindingFlush()
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

                let latestEmpty = self.latestPendingEmptyState
                if self.parent.isTextEmpty != latestEmpty {
                    self.parent.isTextEmpty = latestEmpty
                }

                let rounded = (self.latestPendingHeightValue * 2).rounded() / 2
                if abs(self.parent.dynamicHeight - rounded) > 0.25 {
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
