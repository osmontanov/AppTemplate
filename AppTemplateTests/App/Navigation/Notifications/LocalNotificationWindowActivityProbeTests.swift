#if os(macOS)
import AppKit
import Testing
@testable import AppTemplate

@MainActor
@Suite(.serialized)
struct LocalNotificationWindowActivityProbeTests {
    @Test
    func attachingReportsTheHostingWindowsCurrentKeyState() {
        let center = NotificationCenter()
        let window = NSWindow()
        var reported: [Bool] = []
        let coordinator = LocalNotificationWindowActivityProbe.Coordinator(
            notificationCenter: center,
            onEligibilityChange: { reported.append($0) }
        )
        defer { coordinator.dismantle() }

        coordinator.rebind(to: window)

        #expect(reported == [window.isKeyWindow])
    }

    @Test
    func keyNotificationsAffectOnlyTheCurrentlyBoundWindow() {
        let center = NotificationCenter()
        let boundWindow = NSWindow()
        let otherWindow = NSWindow()
        var reported: [Bool] = []
        let coordinator = LocalNotificationWindowActivityProbe.Coordinator(
            notificationCenter: center,
            onEligibilityChange: { reported.append($0) }
        )
        defer { coordinator.dismantle() }
        coordinator.rebind(to: boundWindow)
        reported.removeAll()

        center.post(name: NSWindow.didBecomeKeyNotification, object: otherWindow)
        center.post(name: NSWindow.didBecomeKeyNotification, object: boundWindow)
        center.post(name: NSWindow.didResignKeyNotification, object: boundWindow)

        #expect(reported == [true, false])
    }

    @Test
    func routineSameWindowUpdatesDoNotReemitAndRebindingFiltersOldWindow() {
        let center = NotificationCenter()
        let first = NSWindow()
        let second = NSWindow()
        var reported: [Bool] = []
        let coordinator = LocalNotificationWindowActivityProbe.Coordinator(
            notificationCenter: center,
            onEligibilityChange: { reported.append($0) }
        )
        defer { coordinator.dismantle() }

        coordinator.rebind(to: first)
        coordinator.rebind(to: first)
        coordinator.rebind(to: second)
        let immediateReports = reported
        center.post(name: NSWindow.didBecomeKeyNotification, object: first)
        center.post(name: NSWindow.didBecomeKeyNotification, object: second)

        #expect(immediateReports.count == 2)
        #expect(reported == immediateReports + [true])
    }

    @Test
    func detachingReportsFalseAndRemovesObservers() {
        let center = NotificationCenter()
        let window = NSWindow()
        var reported: [Bool] = []
        let coordinator = LocalNotificationWindowActivityProbe.Coordinator(
            notificationCenter: center,
            onEligibilityChange: { reported.append($0) }
        )
        coordinator.rebind(to: window)
        reported.removeAll()

        coordinator.dismantle()
        center.post(name: NSWindow.didBecomeKeyNotification, object: window)

        #expect(reported == [false])
    }

    @Test
    func coordinatorDoesNotRetainItsHostingWindow() {
        let reference = WeakObjectReference()
        weak var weakSentinel: WindowLifetimeSentinel?
        do {
            let sentinel = WindowLifetimeSentinel()
            weakSentinel = sentinel
            reference.value = sentinel
        }

        #expect(weakSentinel == nil)
        #expect(reference.value == nil)
    }
}

@MainActor
private final class WindowLifetimeSentinel {}
#endif
