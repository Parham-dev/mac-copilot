import SwiftUI
import AppKit

struct WindowFrameGuard: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = ObserverView()
        view.onWindowChange = { window in
            context.coordinator.bind(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Coordinator {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private var initialPreferredClampPassesRemaining = 0
        private var pendingFrame: NSRect?
        private var hasPendingFrameApply = false

        deinit {
            removeObservers()
        }

        func bind(to window: NSWindow?) {
            guard let window else { return }
            guard self.window !== window else {
                clamp(window: window)
                return
            }

            removeObservers()
            self.window = window
            initialPreferredClampPassesRemaining = 2

            clamp(window: window)

            let center = NotificationCenter.default
            observers.append(
                center.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    guard let self, let window = self.window else { return }
                    self.clamp(window: window)
                }
            )

            observers.append(
                center.addObserver(
                    forName: NSWindow.didChangeScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    guard let self, let window = self.window else { return }
                    self.clamp(window: window)
                }
            )

            observers.append(
                center.addObserver(
                    forName: NSApplication.didChangeScreenParametersNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let self, let window = self.window else { return }
                    self.clamp(window: window)
                }
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self, let window = self.window else { return }
                self.clamp(window: window)
            }
        }

        private func clamp(window: NSWindow) {
            guard let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }

            let horizontalPadding: CGFloat = 20
            let verticalPadding: CGFloat = 24
            let maxWidth = max(visible.width - horizontalPadding, 700)
            let maxHeight = max(visible.height - verticalPadding, 560)

            let preferredMinWidth: CGFloat = 680
            let preferredMinHeight: CGFloat = 660
            let clampedMinWidth = min(preferredMinWidth, maxWidth)
            let clampedMinHeight = min(preferredMinHeight, maxHeight)
            window.minSize = NSSize(width: clampedMinWidth, height: clampedMinHeight)

            if initialPreferredClampPassesRemaining > 0 {
                let preferredLaunchWidth: CGFloat = 820
                let preferredLaunchHeight: CGFloat = 860

                var preferredFrame = window.frame
                preferredFrame.size.width = min(max(preferredLaunchWidth, clampedMinWidth), maxWidth)
                preferredFrame.size.height = min(max(preferredLaunchHeight, clampedMinHeight), maxHeight)
                scheduleFrameApply(window: window, frame: preferredFrame)
                initialPreferredClampPassesRemaining -= 1
            }

            var frame = window.frame
            var changed = false

            if frame.width > maxWidth {
                frame.size.width = maxWidth
                changed = true
            }

            if frame.height > maxHeight {
                frame.size.height = maxHeight
                changed = true
            }

            if frame.minX < visible.minX {
                frame.origin.x = visible.minX
                changed = true
            }

            if frame.maxX > visible.maxX {
                frame.origin.x = visible.maxX - frame.width
                changed = true
            }

            if frame.minY < visible.minY {
                frame.origin.y = visible.minY
                changed = true
            }

            if frame.maxY > visible.maxY {
                frame.origin.y = visible.maxY - frame.height
                changed = true
            }

            if changed {
                scheduleFrameApply(window: window, frame: frame)
            }
        }

        private func scheduleFrameApply(window: NSWindow, frame: NSRect) {
            pendingFrame = frame
            guard !hasPendingFrameApply else { return }

            hasPendingFrameApply = true
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self else { return }
                self.hasPendingFrameApply = false
                guard let window, self.window === window,
                      let frame = self.pendingFrame
                else {
                    self.pendingFrame = nil
                    return
                }

                self.pendingFrame = nil
                if window.frame.equalTo(frame) {
                    return
                }
                window.setFrame(frame, display: true, animate: false)
            }
        }

        private func removeObservers() {
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
            observers.removeAll()
        }
    }

    final class ObserverView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}