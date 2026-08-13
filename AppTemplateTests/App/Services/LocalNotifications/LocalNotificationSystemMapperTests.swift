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
    func contentUsesOneCanonicalEnvelopeKeyForPresentAndMissingData() throws {
        let envelope = Data("trusted-envelope".utf8)

        let present = try LocalNotificationSystemMapper.notificationContent(
            .fixture(sound: .none, envelopeData: envelope)
        )
        let missing = try LocalNotificationSystemMapper.notificationContent(
            .fixture(sound: .none, envelopeData: nil)
        )

        #expect(present.userInfo.count == 1)
        #expect(present.userInfo["AppTemplate.LocalNotification.envelope"] as? Data == envelope)
        #expect(missing.userInfo.isEmpty)
    }

    @Test
    func systemContentReadsOnlyTheCanonicalEnvelopeKey() throws {
        let expected = Data("canonical".utf8)
        let canonical = UNMutableNotificationContent()
        canonical.body = "Body"
        canonical.userInfo = ["AppTemplate.LocalNotification.envelope": expected]
        let wrong = UNMutableNotificationContent()
        wrong.body = "Body"
        wrong.userInfo = ["AppTemplate.LocalNotification.other": Data("wrong".utf8)]

        let canonicalRequest = UNNotificationRequest(identifier: "canonical", content: canonical, trigger: nil)
        let wrongRequest = UNNotificationRequest(identifier: "wrong", content: wrong, trigger: nil)

        #expect(LocalNotificationSystemMapper.systemRequest(canonicalRequest).content.envelopeData == expected)
        #expect(LocalNotificationSystemMapper.systemRequest(wrongRequest).content.envelopeData == nil)
    }

    @Test
    func noneAndDefaultSoundsMapDistinctly() throws {
        let none = try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .none))
        let `default` = try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .default))

        #expect(none.sound == nil)
        #expect(`default`.sound != nil)
    }

    @Test
    func observedSystemSoundRemainsAPlaceholderForLaterEnvelopeOverride() throws {
        let frameworkContent = try LocalNotificationSystemMapper.notificationContent(
            .fixture(sound: .named(resourceName: "reminder.aiff"))
        )
        let request = UNNotificationRequest(
            identifier: "named-sound",
            content: frameworkContent,
            trigger: nil
        )

        let observed = LocalNotificationSystemMapper.systemRequest(request)

        #expect(observed.content.sound == .default)
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
        #expect(roundTrip.options == .init())
    }

    @Test
    func attachmentOptionsUseDictionaryClippingAndResolvedTypeFallback() throws {
        let rectangle = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let attachment = LocalNotificationSystemAttachment(
            identifier: "attachment",
            fileURL: URL(filePath: "/tmp/staged.png"),
            typeIdentifier: "public.png",
            options: .init(
                hidesThumbnail: true,
                thumbnailClippingRect: rectangle,
                thumbnailTime: 1.5
            )
        )

        let options = LocalNotificationSystemMapper.notificationAttachmentOptions(attachment)
        let clipping = try #require(options[UNNotificationAttachmentOptionsThumbnailClippingRectKey])
        var decoded = CGRect.zero

        #expect(options[UNNotificationAttachmentOptionsTypeHintKey] as? String == "public.png")
        #expect(options[UNNotificationAttachmentOptionsThumbnailHiddenKey] as? Bool == true)
        #expect(options[UNNotificationAttachmentOptionsThumbnailTimeKey] as? Double == 1.5)
        #expect(clipping is NSDictionary)
        #expect(CGRectMakeWithDictionaryRepresentation(clipping as! CFDictionary, &decoded))
        #expect(decoded == rectangle)
    }

    @Test
    func explicitAttachmentTypeHintOverridesResolvedType() {
        let attachment = LocalNotificationSystemAttachment(
            identifier: "attachment",
            fileURL: URL(filePath: "/tmp/staged.png"),
            typeIdentifier: "public.png",
            options: .init(typeHint: "public.jpeg")
        )

        let options = LocalNotificationSystemMapper.notificationAttachmentOptions(attachment)

        #expect(options[UNNotificationAttachmentOptionsTypeHintKey] as? String == "public.jpeg")
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
    @MainActor
    func pastAbsoluteCalendarTriggerStopsBeforeNotificationCenterAdd() async throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        let request = LocalNotificationSystemRequest.fixture(
            identifier: "past-calendar",
            trigger: .calendar(components, repeats: false)
        )
        let api = UserNotificationCenterAPISpy()
        let client = UserNotificationCenterClient(api: api)

        await #expect(throws: LocalNotificationSystemMapperError.noNextTriggerDate) {
            try await client.add(request)
        }
        #expect(api.addedRequests.isEmpty)
    }

    @Test
    func futureAndRepeatingCalendarTriggersRetainAFrameworkNextDate() throws {
        var future = DateComponents()
        future.calendar = Calendar(identifier: .gregorian)
        future.timeZone = TimeZone(secondsFromGMT: 0)
        future.year = 2035
        future.month = 1
        future.day = 2
        let futureTrigger = try #require(
            LocalNotificationSystemMapper.notificationTrigger(
                .calendar(future, repeats: false)
            ) as? UNCalendarNotificationTrigger
        )

        var repeating = DateComponents()
        repeating.calendar = Calendar(identifier: .gregorian)
        repeating.timeZone = TimeZone(secondsFromGMT: 0)
        repeating.minute = 7
        let repeatingTrigger = try #require(
            LocalNotificationSystemMapper.notificationTrigger(
                .calendar(repeating, repeats: true)
            ) as? UNCalendarNotificationTrigger
        )

        #expect(futureTrigger.nextTriggerDate() != nil)
        #expect(repeatingTrigger.nextTriggerDate() != nil)
    }

    @Test
    func requestIsMappedBeforeLeavingBoundary() throws {
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
    func systemRequestCapturesIntervalNextDateFromTheRawTriggerOnce() throws {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        let lowerBound = try #require(trigger.nextTriggerDate())
        let request = UNNotificationRequest(
            identifier: "interval",
            content: try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .none)),
            trigger: trigger
        )

        let mapped = LocalNotificationSystemMapper.systemRequest(request)
        let upperBound = try #require(trigger.nextTriggerDate())
        let captured = try #require(mapped.nextTriggerDate)

        #expect(captured >= lowerBound)
        #expect(captured <= upperBound)
        #expect(mapped.nextTriggerDate == captured)
    }

    @Test
    func systemRequestCapturesCalendarNextDateFromTheRawTrigger() throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2035
        components.month = 7
        components.day = 8
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let rawNextDate = try #require(trigger.nextTriggerDate())
        let request = UNNotificationRequest(
            identifier: "calendar",
            content: try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .none)),
            trigger: trigger
        )

        let mapped = LocalNotificationSystemMapper.systemRequest(request)

        #expect(mapped.nextTriggerDate == rawNextDate)
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
    func managedCategoryReplacementRemovesStaleManagedAndPreservesExactForeignObjects() async throws {
        let foreign = UNNotificationCategory.foreign(identifier: "remote.category")
        let prefixAdjacent = UNNotificationCategory.foreign(
            identifier: "AppTemplate.LocalNotification.categoryish.foreign"
        )
        let api = UserNotificationCenterAPISpy(
            categories: [
                foreign,
                prefixAdjacent,
                .foreign(identifier: "AppTemplate.LocalNotification.category.stale")
            ]
        )
        let client = UserNotificationCenterClient(api: api)
        try await client.replaceManagedCategories(
            prefix: "AppTemplate.LocalNotification.category.",
            categories: [.fixture(identifier: "AppTemplate.LocalNotification.category.bG9jYWw")]
        )

        #expect(await api.lastCategoryIdentifiers() == [
            "AppTemplate.LocalNotification.category.bG9jYWw",
            "AppTemplate.LocalNotification.categoryish.foreign",
            "remote.category"
        ])
        #expect(await api.categorySetCount() == 1)
        #expect(api.lastCategories.contains { $0 === foreign })
        #expect(api.lastCategories.contains { $0 === prefixAdjacent })
    }

    @Test
    @MainActor
    func authorizationForwardsOptionsAndReturnsSystemResult() async throws {
        let api = UserNotificationCenterAPISpy(authorizationResult: false)
        let client = UserNotificationCenterClient(api: api)

        let granted = try await client.requestAuthorization([.alert, .badge, .provisional])

        #expect(!granted)
        #expect(api.authorizationOptions == [.alert, .badge, .provisional])
    }

    @Test
    @MainActor
    func authorizationPreservesSystemErrorAndCancellation() async {
        let errorAPI = UserNotificationCenterAPISpy(authorizationError: AdapterTestError.authorization)
        let cancellationAPI = UserNotificationCenterAPISpy(authorizationError: CancellationError())
        let errorClient = UserNotificationCenterClient(api: errorAPI)
        let cancellationClient = UserNotificationCenterClient(api: cancellationAPI)

        await #expect(throws: AdapterTestError.authorization) {
            try await errorClient.requestAuthorization(.sound)
        }
        await #expect(throws: CancellationError.self) {
            try await cancellationClient.requestAuthorization(.sound)
        }
    }

    @Test
    @MainActor
    func addMapsRequestAndPreservesSystemError() async throws {
        let request = LocalNotificationSystemRequest.fixture(
            identifier: "physical.request",
            trigger: .timeInterval(seconds: 90, repeats: false),
            nextTriggerDate: Date(timeIntervalSince1970: 123)
        )
        let successAPI = UserNotificationCenterAPISpy()
        let failureAPI = UserNotificationCenterAPISpy(addError: AdapterTestError.add)
        let successClient = UserNotificationCenterClient(api: successAPI)
        let failureClient = UserNotificationCenterClient(api: failureAPI)

        try await successClient.add(request)
        await #expect(throws: AdapterTestError.add) {
            try await failureClient.add(request)
        }

        #expect(successAPI.addedRequests.map(\.identifier) == ["physical.request"])
        #expect(successAPI.addedRequests.first?.content.body == "Body")
        let trigger = try #require(successAPI.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 90)
        #expect(trigger.repeats == false)
    }

    @Test
    @MainActor
    func rejectedAttachmentMappingStopsBeforeNotificationCenterAdd() async throws {
        let physicalAttachmentID =
            "AppTemplate.LocalNotification.attachment.cmVxdWVzdA.aW1hZ2U"
        let request = LocalNotificationSystemRequest(
            identifier: "AppTemplate.LocalNotification.request.cmVxdWVzdA",
            content: .fixture(
                sound: .none,
                attachments: [
                    LocalNotificationSystemAttachment(
                        identifier: physicalAttachmentID,
                        fileURL: URL(filePath: "/tmp/staged.png"),
                        typeIdentifier: "public.png",
                        options: .init(typeHint: "public.png")
                    )
                ]
            ),
            trigger: .immediate
        )
        let api = UserNotificationCenterAPISpy()
        let client = UserNotificationCenterClient(
            api: api,
            requestMapper: { request in
                try LocalNotificationSystemMapper.notificationRequest(
                    request,
                    attachmentFactory: { _ in throw AdapterTestError.add }
                )
            }
        )

        await #expect(
            throws: LocalNotificationSystemMapperError.attachmentRejected(
                physicalAttachmentID
            )
        ) {
            try await client.add(request)
        }
        #expect(api.addedRequests.isEmpty)
    }

    @Test
    @MainActor
    func preCancelledAddMapsSuccessfullyButStopsBeforeNotificationCenterAdd() async throws {
        let request = LocalNotificationSystemRequest.fixture(
            identifier: "cancel-before-submit"
        )
        let api = UserNotificationCenterAPISpy()
        var mappingCount = 0
        let client = UserNotificationCenterClient(
            api: api,
            requestMapper: { request in
                mappingCount += 1
                return try LocalNotificationSystemMapper.notificationRequest(
                    request
                )
            }
        )
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await client.add(request)
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(mappingCount == 1)
        #expect(api.addedRequests.isEmpty)
    }

    @Test
    @MainActor
    func pendingMapsRequestsAndCapturesTheirRawNextDates() async throws {
        var calendarComponents = DateComponents()
        calendarComponents.calendar = Calendar(identifier: .gregorian)
        calendarComponents.timeZone = TimeZone(secondsFromGMT: 0)
        calendarComponents.year = 2036
        calendarComponents.month = 4
        calendarComponents.day = 5
        calendarComponents.hour = 6
        let intervalTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 45, repeats: false)
        let calendarTrigger = UNCalendarNotificationTrigger(
            dateMatching: calendarComponents,
            repeats: false
        )
        let requests = [
            UNNotificationRequest(
                identifier: "interval",
                content: try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .none)),
                trigger: intervalTrigger
            ),
            UNNotificationRequest(
                identifier: "calendar",
                content: try LocalNotificationSystemMapper.notificationContent(.fixture(sound: .none)),
                trigger: calendarTrigger
            )
        ]
        let intervalLowerBound = try #require(intervalTrigger.nextTriggerDate())
        let calendarNextDate = try #require(calendarTrigger.nextTriggerDate())
        let api = UserNotificationCenterAPISpy(pendingRequests: requests)
        let client = UserNotificationCenterClient(api: api)

        let mapped = await client.pending()
        let intervalUpperBound = try #require(intervalTrigger.nextTriggerDate())

        let mappedInterval = try #require(mapped.first { $0.identifier == "interval" })
        let capturedInterval = try #require(mappedInterval.nextTriggerDate)
        #expect(capturedInterval >= intervalLowerBound)
        #expect(capturedInterval <= intervalUpperBound)
        #expect(mapped.first { $0.identifier == "calendar" }?.nextTriggerDate == calendarNextDate)
    }

    @Test
    @MainActor
    func deliveredMapsAnEmptyFrameworkCollectionWithoutUnsafeFixtures() async {
        let api = UserNotificationCenterAPISpy(deliveredNotifications: [])
        let client = UserNotificationCenterClient(api: api)

        #expect(await client.delivered().isEmpty)
        #expect(api.deliveredFetchCount == 1)
    }

    @Test
    @MainActor
    func scopedRemovalsForwardSortedIdentifiers() async {
        let api = UserNotificationCenterAPISpy()
        let client = UserNotificationCenterClient(api: api)

        await client.removePending(["z", "a", "m"])
        await client.removeDelivered(["3", "1", "2"])

        #expect(api.pendingRemovalIdentifiers == [["a", "m", "z"]])
        #expect(api.deliveredRemovalIdentifiers == [["1", "2", "3"]])
    }

    @Test
    @MainActor
    func badgeForwardsCountAndPreservesSystemError() async throws {
        let successAPI = UserNotificationCenterAPISpy()
        let failureAPI = UserNotificationCenterAPISpy(badgeError: AdapterTestError.badge)
        let successClient = UserNotificationCenterClient(api: successAPI)
        let failureClient = UserNotificationCenterClient(api: failureAPI)

        try await successClient.setBadgeCount(12)
        await #expect(throws: AdapterTestError.badge) {
            try await failureClient.setBadgeCount(13)
        }

        #expect(successAPI.badgeCounts == [12])
        #expect(failureAPI.badgeCounts == [13])
    }

    @Test
    func scriptedClientRecordsResultsAndExactOperationOrder() async throws {
        let settings = LocalNotificationSettings.fixture()
        let request = LocalNotificationSystemRequest.fixture(identifier: "request")
        let delivered = LocalNotificationSystemDelivered(
            request: request,
            deliveredAt: Date(timeIntervalSince1970: 456)
        )
        let category = LocalNotificationSystemCategory.fixture(identifier: "category")
        let client = ScriptedLocalNotificationCenterClient(
            settings: settings,
            authorizationResult: .success(false),
            pending: [request],
            delivered: [delivered]
        )

        #expect(await client.settings() == settings)
        #expect(try await client.requestAuthorization(.alert) == false)
        try await client.replaceManagedCategories(prefix: "managed.", categories: [category])
        try await client.add(request)
        #expect(await client.pending() == [request])
        #expect(await client.delivered() == [delivered])
        await client.removePending(["pending"])
        await client.removeDelivered(["delivered"])
        try await client.setBadgeCount(8)

        #expect(await client.operations() == [
            .settings,
            .requestAuthorization(.alert),
            .replaceManagedCategories(prefix: "managed.", categories: [category]),
            .add(request),
            .pending,
            .delivered,
            .removePending(["pending"]),
            .removeDelivered(["delivered"]),
            .setBadgeCount(8)
        ])
    }

    @Test
    func scriptedClientRecordsOperationsBeforeReturningInjectedErrors() async {
        let client = ScriptedLocalNotificationCenterClient(
            settings: .fixture(),
            authorizationResult: .failure(AdapterTestError.authorization),
            categoryError: AdapterTestError.category,
            addError: AdapterTestError.add,
            badgeError: AdapterTestError.badge
        )
        let category = LocalNotificationSystemCategory.fixture(identifier: "category")
        let request = LocalNotificationSystemRequest.fixture(identifier: "request")

        await #expect(throws: AdapterTestError.authorization) {
            try await client.requestAuthorization(.sound)
        }
        await #expect(throws: AdapterTestError.category) {
            try await client.replaceManagedCategories(prefix: "managed.", categories: [category])
        }
        await #expect(throws: AdapterTestError.add) {
            try await client.add(request)
        }
        await #expect(throws: AdapterTestError.badge) {
            try await client.setBadgeCount(4)
        }

        #expect(await client.operations() == [
            .requestAuthorization(.sound),
            .replaceManagedCategories(prefix: "managed.", categories: [category]),
            .add(request),
            .setBadgeCount(4)
        ])
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
    static func fixture(
        sound: LocalNotificationSystemSound,
        envelopeData: Data? = nil,
        attachments: [LocalNotificationSystemAttachment] = []
    ) -> Self {
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
            attachments: attachments,
            envelopeData: envelopeData
        )
    }
}

private nonisolated extension LocalNotificationSystemRequest {
    static func fixture(
        identifier: String,
        trigger: LocalNotificationSystemTrigger = .immediate,
        nextTriggerDate: Date? = nil
    ) -> Self {
        .init(
            identifier: identifier,
            content: .fixture(sound: .none),
            trigger: trigger,
            nextTriggerDate: nextTriggerDate
        )
    }
}

private nonisolated extension LocalNotificationSettings {
    static func fixture() -> Self {
        .init(
            authorizationStatus: .authorized,
            alertSetting: .enabled,
            soundSetting: .enabled,
            badgeSetting: .enabled,
            notificationCenterSetting: .enabled,
            lockScreenSetting: .enabled,
            alertStyle: .banner,
            previewSetting: .always
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
    private let authorizationResult: Bool
    private let authorizationError: (any Error)?
    private let addError: (any Error)?
    private let pendingRequests: [UNNotificationRequest]
    private let deliveredNotificationsResult: [UNNotification]
    private let badgeError: (any Error)?

    private(set) var authorizationOptions: UNAuthorizationOptions?
    private(set) var lastCategories: Set<UNNotificationCategory> = []
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var deliveredFetchCount = 0
    private(set) var pendingRemovalIdentifiers: [[String]] = []
    private(set) var deliveredRemovalIdentifiers: [[String]] = []
    private(set) var badgeCounts: [Int] = []

    init(
        categories: Set<UNNotificationCategory> = [],
        authorizationResult: Bool = true,
        authorizationError: (any Error)? = nil,
        addError: (any Error)? = nil,
        pendingRequests: [UNNotificationRequest] = [],
        deliveredNotifications: [UNNotification] = [],
        badgeError: (any Error)? = nil
    ) {
        self.categories = categories
        self.authorizationResult = authorizationResult
        self.authorizationError = authorizationError
        self.addError = addError
        self.pendingRequests = pendingRequests
        deliveredNotificationsResult = deliveredNotifications
        self.badgeError = badgeError
        storage = UserNotificationCenterAPISpyStorage()
    }

    func notificationSettings() async -> UNNotificationSettings { fatalError("unused") }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationOptions = options
        if let authorizationError { throw authorizationError }
        return authorizationResult
    }
    func notificationCategories() async -> Set<UNNotificationCategory> { categories }
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async {
        lastCategories = categories
        await storage.record(categories.map(\.identifier).sorted())
    }
    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        if let addError { throw addError }
    }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { pendingRequests }
    func deliveredNotifications() async -> [UNNotification] {
        deliveredFetchCount += 1
        return deliveredNotificationsResult
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        pendingRemovalIdentifiers.append(identifiers)
    }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async {
        deliveredRemovalIdentifiers.append(identifiers)
    }
    func setBadgeCount(_ count: Int) async throws {
        badgeCounts.append(count)
        if let badgeError { throw badgeError }
    }

    func lastCategoryIdentifiers() async -> [String] { await storage.lastIdentifiers() }
    func categorySetCount() async -> Int { await storage.count() }
}

private actor UserNotificationCenterAPISpyStorage {
    private var categorySets: [[String]] = []

    func record(_ identifiers: [String]) { categorySets.append(identifiers) }
    func lastIdentifiers() -> [String] { categorySets.last ?? [] }
    func count() -> Int { categorySets.count }
}

private nonisolated enum AdapterTestError: Error, Equatable, Sendable {
    case authorization
    case category
    case add
    case badge
}
