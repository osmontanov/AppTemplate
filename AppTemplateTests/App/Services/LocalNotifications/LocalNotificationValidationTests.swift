import Foundation
import CoreGraphics
import Testing
@testable import AppTemplate

nonisolated
struct LocalNotificationValidationTests {
    @Test
    func intervalBoundariesAreExact() throws {
        try LocalNotificationValidator.validate(trigger: .timeInterval(seconds: 0.001, repeats: false))
        #expect(throws: LocalNotificationServiceError.self) {
            try LocalNotificationValidator.validate(trigger: .timeInterval(seconds: 59.999, repeats: true))
        }
        try LocalNotificationValidator.validate(trigger: .timeInterval(seconds: 60, repeats: true))
    }

    @Test
    func contentMustHaveAnObservableEffect() throws {
        let empty = LocalNotificationContent(title: " ", subtitle: "", body: "\n")
        #expect(throws: LocalNotificationServiceError.invalidContent(.notObservable)) {
            try LocalNotificationValidator.validate(content: empty)
        }

        let badgeOnly = LocalNotificationContent(badge: 0)
        try LocalNotificationValidator.validate(content: badgeOnly)
    }

    @Test(arguments: ["NUL\u{0000}", "\u{0000}"])
    func contentRejectsNULText(_ text: String) {
        let content = LocalNotificationContent(title: text)
        #expect(throws: LocalNotificationServiceError.invalidContent(.containsNUL)) {
            try LocalNotificationValidator.validate(content: content)
        }
    }

    @Test
    func contentEnforcesBadgeSummaryAndRelevanceRules() {
        #expect(throws: LocalNotificationServiceError.invalidContent(.invalidBadge)) {
            try LocalNotificationValidator.validate(content: LocalNotificationContent(title: "Title", badge: -1))
        }
        #expect(throws: LocalNotificationServiceError.invalidContent(.invalidSummaryArgument)) {
            try LocalNotificationValidator.validate(content: LocalNotificationContent(title: "Title", summaryArgument: " ", summaryArgumentCount: 1))
        }
        #expect(throws: LocalNotificationServiceError.invalidContent(.invalidSummaryArgumentCount)) {
            try LocalNotificationValidator.validate(content: LocalNotificationContent(title: "Title", summaryArgument: "Summary", summaryArgumentCount: 0))
        }
        #expect(throws: LocalNotificationServiceError.invalidContent(.invalidRelevanceScore)) {
            try LocalNotificationValidator.validate(content: LocalNotificationContent(title: "Title", relevanceScore: .infinity))
        }
    }

    @Test(arguments: ["", "folder/sound.aiff", "folder\\sound.aiff", "sound\u{0000}.aiff"])
    func namedSoundRequiresALeafResourceName(_ name: String) {
        let content = LocalNotificationContent(title: "Title", sound: .named(resourceName: name))
        #expect(throws: LocalNotificationServiceError.invalidContent(.invalidSoundName)) {
            try LocalNotificationValidator.validate(content: content)
        }
    }

    @Test
    func foregroundOptionsRejectUnknownBits() {
        #expect(throws: LocalNotificationServiceError.invalidContent(.invalidForegroundPresentation)) {
            try LocalNotificationValidator.validate(
                content: LocalNotificationContent(
                    title: "Title",
                    foregroundPresentation: LocalNotificationForegroundPresentation(rawValue: 1 << 20)
                )
            )
        }
    }

    @Test
    func calendarAllowsOnlyMatchingFieldsAndRequiresANextDate() throws {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        try LocalNotificationValidator.validate(
            trigger: .calendar(DateComponents(hour: 10), repeats: true),
            calendar: calendar,
            referenceDate: referenceDate
        )

        #expect(throws: LocalNotificationServiceError.invalidTrigger(.unsupportedCalendarComponent)) {
            try LocalNotificationValidator.validate(
                trigger: .calendar(DateComponents(nanosecond: 1), repeats: false),
                calendar: calendar,
                referenceDate: referenceDate
            )
        }
        #expect(throws: LocalNotificationServiceError.invalidTrigger(.noNextTriggerDate)) {
            try LocalNotificationValidator.validate(
                trigger: .calendar(DateComponents(year: 1, month: 2, day: 30), repeats: false),
                calendar: calendar,
                referenceDate: referenceDate
            )
        }
    }

    @Test
    func attachmentOptionNumbersMustBeFiniteAndInRange() {
        let invalidRectangle = LocalNotificationAttachmentOptions(
            thumbnailClippingRect: CGRect(x: 0, y: 0, width: 1.1, height: 1)
        )
        let invalidTime = LocalNotificationAttachmentOptions(thumbnailTime: -.infinity)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(
            try! LocalNotificationAttachmentID("image"), .invalidOptions
        )) {
            try LocalNotificationValidator.validate(
                attachment: LocalNotificationAttachment(
                    id: try! LocalNotificationAttachmentID("image"),
                    fileURL: URL(fileURLWithPath: "/tmp/image"),
                    options: invalidRectangle
                )
            )
        }
        #expect(throws: LocalNotificationServiceError.self) {
            try LocalNotificationValidator.validate(
                attachment: LocalNotificationAttachment(
                    id: try! LocalNotificationAttachmentID("image"),
                    fileURL: URL(fileURLWithPath: "/tmp/image"),
                    options: invalidTime
                )
            )
        }
    }

    @Test
    func categoryRequiresUniqueActionsAndAtMostTen() throws {
        let duplicateID = try LocalNotificationActionID("open")
        let duplicateActions = LocalNotificationCategory(
            id: try LocalNotificationCategoryID("category"),
            actions: [
                .button(LocalNotificationButtonAction(id: duplicateID, title: "Open")),
                .button(LocalNotificationButtonAction(id: duplicateID, title: "Again"))
            ]
        )
        #expect(throws: LocalNotificationServiceError.invalidCategory(.duplicateActionID)) {
            try LocalNotificationValidator.validate(category: duplicateActions)
        }

        let actions = try (0...10).map { index in
            LocalNotificationAction.button(
                LocalNotificationButtonAction(
                    id: try LocalNotificationActionID("action-\(index)"),
                    title: "Action \(index)"
                )
            )
        }
        #expect(throws: LocalNotificationServiceError.invalidCategory(.tooManyActions)) {
            try LocalNotificationValidator.validate(
                category: LocalNotificationCategory(
                    id: try LocalNotificationCategoryID("category"), actions: actions
                )
            )
        }
    }
}
