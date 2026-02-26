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
        context.coordinator.updateEmptyState(textView.string)

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

        context.coordinator.updateParent(self)

        textView.onShiftEnter = onShiftEnter
        textView.isEditable = isEditable

        if context.coordinator.shouldDeferBindingToTextViewSync(boundText: text) {
            return
        }

        if textView.string != text {
            textView.string = text
            context.coordinator.updateScrollerOnly(for: textView)
            context.coordinator.updateEmptyState(textView.string)
            context.coordinator.updateHeight(for: textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var parent: ComposerTextView
        private var pendingTextUpdate = false
        private var latestPendingTextValue = ""
        private var pendingEmptyStateUpdate = false
        private var latestPendingEmptyState = true
        private var pendingHeightUpdate = false
        private var latestPendingHeightValue: CGFloat = 0

        init(parent: ComposerTextView) {
            self.parent = parent
        }

        func updateParent(_ parent: ComposerTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            enqueueTextBindingUpdate(textView.string)
            updateEmptyState(textView.string)
            updateHeight(for: textView)
        }

        func updateEmptyState(_ value: String) {
            let empty = value.isEmpty
            latestPendingEmptyState = empty
            guard !pendingEmptyStateUpdate else { return }
            pendingEmptyStateUpdate = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingEmptyStateUpdate = false
                let latest = self.latestPendingEmptyState
                if self.parent.isTextEmpty != latest {
                    self.parent.isTextEmpty = latest
                }
            }
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

        func shouldDeferBindingToTextViewSync(boundText: String) -> Bool {
            pendingTextUpdate && boundText != latestPendingTextValue
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
