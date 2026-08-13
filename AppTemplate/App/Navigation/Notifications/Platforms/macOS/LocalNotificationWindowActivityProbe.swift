#if os(macOS)
import AppKit
import Foundation
import SwiftUI

struct LocalNotificationWindowActivityProbe: NSViewRepresentable {
    private let notificationCenter: NotificationCenter
    private let onEligibilityChange: @MainActor (Bool) -> Void

    init(
        notificationCenter: NotificationCenter = .default,
        onEligibilityChange: @escaping @MainActor (Bool) -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.onEligibilityChange = onEligibilityChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            notificationCenter: notificationCenter,
            onEligibilityChange: onEligibilityChange
        )
    }

    func makeNSView(context: Context) -> HostingWindowProbeView {
        let view = HostingWindowProbeView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(
        _ nsView: HostingWindowProbeView,
        context: Context
    ) {
        nsView.coordinator = context.coordinator
        context.coordinator.update(onEligibilityChange: onEligibilityChange)
        context.coordinator.rebind(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: HostingWindowProbeView,
        coordinator: Coordinator
    ) {
        nsView.coordinator = nil
        coordinator.dismantle()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let notificationCenter: NotificationCenter
        private var onEligibilityChange: @MainActor (Bool) -> Void
        private let currentWindow = WeakObjectReference()
        private var isObserving = false

        init(
            notificationCenter: NotificationCenter,
            onEligibilityChange: @escaping @MainActor (Bool) -> Void
        ) {
            self.notificationCenter = notificationCenter
            self.onEligibilityChange = onEligibilityChange
            super.init()
        }

        deinit { notificationCenter.removeObserver(self) }

        func update(
            onEligibilityChange: @escaping @MainActor (Bool) -> Void
        ) {
            self.onEligibilityChange = onEligibilityChange
        }

        func rebind(to window: NSWindow?) {
            guard currentWindow.value as? NSWindow !== window else { return }
            removeObservers()
            currentWindow.value = window
            guard let window else {
                onEligibilityChange(false)
                return
            }
            notificationCenter.addObserver(
                self,
                selector: #selector(windowDidBecomeKey(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(windowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: nil
            )
            isObserving = true
            onEligibilityChange(window.isKeyWindow)
        }

        func dismantle() {
            removeObservers()
            currentWindow.value = nil
            onEligibilityChange(false)
        }

        @objc
        private func windowDidBecomeKey(_ notification: Notification) {
            guard notification.object as? NSWindow
                === currentWindow.value as? NSWindow else {
                return
            }
            onEligibilityChange(true)
        }

        @objc
        private func windowDidResignKey(_ notification: Notification) {
            guard notification.object as? NSWindow
                === currentWindow.value as? NSWindow else {
                return
            }
            onEligibilityChange(false)
        }

        private func removeObservers() {
            guard isObserving else { return }
            notificationCenter.removeObserver(self)
            isObserving = false
        }
    }
}

@MainActor
final class WeakObjectReference {
    weak var value: AnyObject?
}

@MainActor
final class HostingWindowProbeView: NSView {
    weak var coordinator: LocalNotificationWindowActivityProbe.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.rebind(to: window)
    }
}
#endif
