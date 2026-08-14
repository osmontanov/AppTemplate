import XCTest

nonisolated
final class ProductReminderUITests: XCTestCase {
    @MainActor
    func testInMemoryQuickReminderAndCancel() throws {
        let appRobot = try AppRobot.launchProductReminder()
        let store = appRobot.store()

        try store.openProduct("Reminder Phone")
        try store.openCurrentProductReminder()
        try store.scheduleQuickReminder()
        try store.cancelCurrentProductReminder()

        try appRobot.waitForScriptExhaustion()
    }
}
