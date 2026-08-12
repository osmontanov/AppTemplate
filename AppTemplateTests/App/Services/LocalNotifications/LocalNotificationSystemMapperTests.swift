import CoreGraphics
import Foundation
import Testing
import UserNotifications
@testable import AppTemplate

nonisolated
struct LocalNotificationSystemMapperTests {
    @Test
    func authorizationOptionsMapEveryApprovedBit() {
        let mapped = LocalNotificationSystemMapper.authorizationOptions([
            .alert, .sound, .badge, .provisional
        ])

        #expect(mapped == [.alert, .sound, .badge, .provisional])
    }

    @Test
    func authorizationStatusesMapKnownUnsupportedAndUnknownValues() {
        #expect(LocalNotificationSystemMapper.authorizationStatus(.notDetermined) == .notDetermined)
        #expect(LocalNotificationSystemMapper.authorizationStatus(.denied) == .denied)
        #expect(LocalNotificationSystemMapper.authorizationStatus(.authorized) == .authorized)
        #expect(LocalNotificationSystemMapper.authorizationStatus(.provisional) == .provisional)
#if os(iOS)
        #expect(LocalNotificationSystemMapper.authorizationStatus(.ephemeral) == .ephemeral)
#else
        #expect(LocalNotificationSystemMapper.authorizationStatus(nil) == .notSupported)
#endif
        #expect(LocalNotificationSystemMapper.authorizationStatus(.init(rawValue: 999)) == .unknown)
    }

    @Test
    func settingStatesMapEveryKnownAndUnknownValue() {
        #expect(LocalNotificationSystemMapper.settingState(.notSupported) == .notSupported)
        #expect(LocalNotificationSystemMapper.settingState(.disabled) == .disabled)
        #expect(LocalNotificationSystemMapper.settingState(.enabled) == .enabled)
        #expect(LocalNotificationSystemMapper.settingState(.init(rawValue: 999)!) == .unknown)
    }

    @Test
    func alertStylesAndPreviewSettingsMapEveryKnownUnsupportedAndUnknownValue() {
        #expect(LocalNotificationSystemMapper.alertStyle(UNAlertStyle.none) == .none)
        #expect(LocalNotificationSystemMapper.alertStyle(.banner) == .banner)
        #expect(LocalNotificationSystemMapper.alertStyle(.alert) == .alert)
        #expect(LocalNotificationSystemMapper.alertStyle(nil) == .notSupported)
        #expect(LocalNotificationSystemMapper.alertStyle(.init(rawValue: 999)) == .unknown)

        #expect(LocalNotificationSystemMapper.previewSetting(.always) == .always)
        #expect(LocalNotificationSystemMapper.previewSetting(.whenAuthenticated) == .whenAuthenticated)
        #expect(LocalNotificationSystemMapper.previewSetting(.never) == .never)
        #expect(LocalNotificationSystemMapper.previewSetting(nil) == .notSupported)
        #expect(LocalNotificationSystemMapper.previewSetting(.init(rawValue: 999)) == .unknown)
    }

    @Test
    func foregroundPresentationMapsEveryApprovedBit() {
        let mapped = LocalNotificationSystemMapper.presentationOptions([
            .banner, .list, .sound, .badge
        ])

        #expect(mapped == [.banner, .list, .sound, .badge])
    }

    @Test(arguments: [
        (LocalNotificationInterruptionLevel.passive, UNNotificationInterruptionLevel.passive),
        (LocalNotificationInterruptionLevel.active, UNNotificationInterruptionLevel.active)
    ])
    func interruptionLevelMapsOnlyApprovedCases(
        _ logical: LocalNotificationInterruptionLevel,
        _ expected: UNNotificationInterruptionLevel
    ) {
        #expect(LocalNotificationSystemMapper.interruptionLevel(logical) == expected)
    }

    @Test
    func contentMapsEveryFieldAndNamedSound() throws {
        let envelope = Data(#"{"schemaVersion":1}"#.utf8)
        let content = LocalNotificationSystemContent(
            title: "Title",
            subtitle: "Subtitle",
            body: "Body",
            badge: 7,
            sound: .named(resourceName: "reminder.aiff"),
            categoryIdentifier: "managed.category",
            threadIdentifier: "thread",
            targetContentIdentifier: "target",
            summaryArgument: "Project",
            summaryArgumentCount: 3,
            relevanceScore: 0.75,
            interruptionLevel: .passive,
            attachments: [],
            envelopeKey: "AppTemplate.LocalNotification.envelope",
            envelopeData: envelope
        )

        let mapped = try LocalNotificationSystemMapper.notificationContent(content)

        #expect(mapped.title == "Title")
        #expect(mapped.subtitle == "Subtitle")
        #expect(mapped.body == "Body")
        #expect(mapped.badge == 7)
        #expect(mapped.sound != nil)
        #expect(mapped.categoryIdentifier == "managed.category")
        #expect(mapped.threadIdentifier == "thread")
        #expect(mapped.targetContentIdentifier == "target")
#if os(iOS)
        #expect(mapped.value(forKey: "summaryArgument") as? String == "Project")
        #expect((mapped.value(forKey: "summaryArgumentCount") as? NSNumber)?.intValue == 3)
#else
        #expect(mapped.summaryArgument == "Project")
        #expect(mapped.summaryArgumentCount == 3)
#endif
        #expect(mapped.relevanceScore == 0.75)
        #expect(mapped.interruptionLevel == .passive)
        #expect(mapped.attachments.isEmpty)
        #expect(mapped.userInfo.count == 1)
        #expect(mapped.userInfo["AppTemplate.LocalNotification.envelope"] as? Data == envelope)
    }

    @Test
    func noneAndDefaultSoundsMapDistinctly() throws {
        let none = try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .none))
        let `default` = try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .default))

        #expect(none.sound == nil)
        #expect(`default`.sound != nil)
    }

    @Test
    func attachmentMapsOptionsAndRoundTripsSystemOwnedState() throws {
        let url = try temporaryPNG()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let attachment = LocalNotificationSystemAttachment(
            identifier: "attachment",
            fileURL: url,
            typeIdentifier: "public.png",
            options: .init(
                typeHint: "public.png",
                hidesThumbnail: true,
                thumbnailClippingRect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                thumbnailTime: 1.5
            )
        )

        let mapped = try LocalNotificationSystemMapper.notificationAttachment(attachment)
        let roundTrip = LocalNotificationSystemMapper.systemAttachment(mapped)

        #expect(mapped.identifier == "attachment")
        #expect(roundTrip.identifier == "attachment")
        #expect(roundTrip.fileURL == mapped.url)
        #expect(roundTrip.typeIdentifier == mapped.type)
    }

    @Test
    func immediateIntervalAndCalendarTriggersMapExactly() throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 3_600)
        components.weekday = 2
        components.hour = 9
        components.minute = 30

        #expect(try LocalNotificationSystemMapper.notificationTrigger(.immediate) == nil)
        let interval = try #require(
            LocalNotificationSystemMapper.notificationTrigger(.timeInterval(seconds: 90, repeats: true))
                as? UNTimeIntervalNotificationTrigger
        )
        #expect(interval.timeInterval == 90)
        #expect(interval.repeats)

        let calendar = try #require(
            LocalNotificationSystemMapper.notificationTrigger(.calendar(components, repeats: false))
                as? UNCalendarNotificationTrigger
        )
        #expect(calendar.dateComponents.calendar?.identifier == .gregorian)
        #expect(calendar.dateComponents.timeZone?.secondsFromGMT() == 3_600)
        #expect(calendar.dateComponents.weekday == 2)
        #expect(calendar.dateComponents.hour == 9)
        #expect(calendar.dateComponents.minute == 30)
        #expect(!calendar.repeats)
    }

    @Test
    func requestAndDeliveredObjectsAreMappedBeforeLeavingBoundary() throws {
        let request = UNNotificationRequest(
            identifier: "physical.request",
            content: try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .none)),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        )

        let mapped = LocalNotificationSystemMapper.systemRequest(request)

        #expect(mapped.identifier == "physical.request")
        #expect(mapped.content.body == "Body")
        #expect(mapped.trigger == .timeInterval(seconds: 30, repeats: false))
    }

    @Test
    func categoryDTOCarriesEveryFieldBeforeTheFrameworkBoundary() {
        let category = LocalNotificationSystemCategory.fixture(
            identifier: "managed.category",
            hiddenPreviewsBodyPlaceholder: "Hidden body",
            categorySummaryFormat: "%u items"
        )

        #expect(category.hiddenPreviewsBodyPlaceholder == "Hidden body")
        #expect(category.categorySummaryFormat == "%u items")
    }

    @Test
    func categoryMapsOrderedButtonAndTextInputActionsAndOptions() throws {
        let category = LocalNotificationSystemCategory(
            identifier: "managed.category",
            actions: [
                .button(.init(
                    identifier: "open",
                    title: "Open",
                    options: [.foreground, .destructive]
                )),
                .textInput(.init(
                    identifier: "reply",
                    title: "Reply",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Message"
                ))
            ],
            hiddenPreviewsBodyPlaceholder: "Hidden body",
            categorySummaryFormat: "%u items",
            hiddenPreviewsShowTitle: true,
            hiddenPreviewsShowSubtitle: true,
            reportsDismissal: true
        )

        let mapped = LocalNotificationSystemMapper.notificationCategory(category)

        #expect(mapped.identifier == "managed.category")
        #expect(mapped.actions.map(\.identifier) == ["open", "reply"])
        #expect(mapped.actions[0].title == "Open")
        #expect(mapped.actions[0].options == [.foreground, .destructive])
        let text = try #require(mapped.actions[1] as? UNTextInputNotificationAction)
        #expect(text.title == "Reply")
        #expect(text.options == [.authenticationRequired])
        #expect(text.textInputButtonTitle == "Send")
        #expect(text.textInputPlaceholder == "Message")
        #expect(mapped.options.contains(.hiddenPreviewsShowTitle))
        #expect(mapped.options.contains(.hiddenPreviewsShowSubtitle))
        #expect(mapped.options.contains(.customDismissAction))
#if os(iOS)
        #expect(mapped.hiddenPreviewsBodyPlaceholder == "Hidden body")
        #expect(mapped.categorySummaryFormat == "%u items")
#else
        // macOS has no category initializer capable of representing these two strings.
        #expect(mapped.actions.count == 2)
#endif
    }

    @Test
    @MainActor
    func managedCategoryReplacementPreservesForeignCategories() async throws {
        let api = UserNotificationCenterAPISpy(
            categories: [.foreign(identifier: "remote.category")]
        )
        let client = UserNotificationCenterClient(api: api)
        try await client.replaceManagedCategories(
            prefix: "AppTemplate.LocalNotification.category.",
            categories: [.fixture(identifier: "AppTemplate.LocalNotification.category.bG9jYWw")]
        )

        #expect(await api.lastCategoryIdentifiers() == [
            "AppTemplate.LocalNotification.category.bG9jYWw",
            "remote.category"
        ])
        #expect(await api.categorySetCount() == 1)
    }

    private func temporaryPNG() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let url = directory.appending(path: "pixel.png")
        let bytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        try bytes.write(to: url)
        return url
    }
}

private nonisolated extension LocalNotificationSystemContent {
    static func fixture(sound: LocalNotificationSystemSound) -> Self {
        .init(
            title: "",
            subtitle: "",
            body: "Body",
            badge: nil,
            sound: sound,
            categoryIdentifier: nil,
            threadIdentifier: nil,
            targetContentIdentifier: nil,
            summaryArgument: nil,
            summaryArgumentCount: nil,
            relevanceScore: nil,
            interruptionLevel: .active,
            attachments: [],
            envelopeKey: "AppTemplate.LocalNotification.envelope",
            envelopeData: nil
        )
    }
}

private nonisolated extension LocalNotificationSystemCategory {
    static func fixture(
        identifier: String,
        hiddenPreviewsBodyPlaceholder: String? = nil,
        categorySummaryFormat: String? = nil
    ) -> Self {
        .init(
            identifier: identifier,
            actions: [],
            hiddenPreviewsBodyPlaceholder: hiddenPreviewsBodyPlaceholder,
            categorySummaryFormat: categorySummaryFormat,
            hiddenPreviewsShowTitle: false,
            hiddenPreviewsShowSubtitle: false,
            reportsDismissal: false
        )
    }
}

private extension UNNotificationCategory {
    static func foreign(identifier: String) -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: identifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
    }
}

@MainActor
private final class UserNotificationCenterAPISpy: UserNotificationCenterAPI {
    private let storage: UserNotificationCenterAPISpyStorage
    private let categories: Set<UNNotificationCategory>

    init(categories: Set<UNNotificationCategory>) {
        self.categories = categories
        storage = UserNotificationCenterAPISpyStorage()
    }

    func notificationSettings() async -> UNNotificationSettings { fatalError("unused") }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { fatalError("unused") }
    func notificationCategories() async -> Set<UNNotificationCategory> { categories }
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async {
        await storage.record(categories.map(\.identifier).sorted())
    }
    func add(_ request: UNNotificationRequest) async throws { fatalError("unused") }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { fatalError("unused") }
    func deliveredNotifications() async -> [UNNotification] { fatalError("unused") }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async { fatalError("unused") }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async { fatalError("unused") }
    func setBadgeCount(_ count: Int) async throws { fatalError("unused") }

    func lastCategoryIdentifiers() async -> [String] { await storage.lastIdentifiers() }
    func categorySetCount() async -> Int { await storage.count() }
}

private actor UserNotificationCenterAPISpyStorage {
    private var categorySets: [[String]] = []

    func record(_ identifiers: [String]) { categorySets.append(identifiers) }
    func lastIdentifiers() -> [String] { categorySets.last ?? [] }
    func count() -> Int { categorySets.count }
}
