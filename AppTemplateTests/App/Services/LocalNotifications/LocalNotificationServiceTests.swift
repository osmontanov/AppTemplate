import Foundation
import Testing
@testable import AppTemplate

struct LocalNotificationServiceTests {
    @Test
    func settingsReturnTheSystemSnapshotWithoutRequestingAuthorization() async {
        let expected = LocalNotificationSettings.serviceFixture(authorizationStatus: .denied)
        let client = ScriptedLocalNotificationCenterClient(settings: expected)
        let service = LocalNotificationService.fixture(client: client)

        #expect(await service.settings() == expected)
        #expect(await client.operations() == [.settings])
    }

    @Test(arguments: [true, false])
    func authorizationValidatesForwardsAndReturnsTheSystemOutcome(_ granted: Bool) async throws {
        let client = ScriptedLocalNotificationCenterClient(authorizationResult: .success(granted))
        let service = LocalNotificationService.fixture(client: client)
        let options: LocalNotificationAuthorizationOptions = [.alert, .sound, .badge]

        #expect(try await service.requestAuthorization(options) == granted)
        #expect(await client.operations() == [.requestAuthorization(options)])

        await #expect(throws: LocalNotificationServiceError.invalidAuthorizationOptions) {
            _ = try await service.requestAuthorization([])
        }
        #expect(await client.operations() == [.requestAuthorization(options)])
    }

    @Test
    func authorizationRedactsSystemErrorsAndPreservesCancellation() async {
        let privateError = NSError(
            domain: "NotificationAuthorization",
            code: 41,
            userInfo: [NSLocalizedDescriptionKey: "PRIVATE-AUTHORIZATION-DESCRIPTION"]
        )
        let failing = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(
                authorizationResult: .failure(privateError)
            )
        )
        let cancelling = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(
                authorizationResult: .failure(CancellationError())
            )
        )

        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .authorization,
                domain: "NotificationAuthorization",
                code: 41
            )
        ) {
            _ = try await failing.requestAuthorization(.alert)
        }
        let description = LocalNotificationServiceError.system(
            operation: .authorization,
            domain: "NotificationAuthorization",
            code: 41
        ).errorDescription
        #expect(description == "Local notification system operation failed.")
        #expect(description?.contains("PRIVATE") == false)

        let cancellation = await capturedError {
            _ = try await cancelling.requestAuthorization(.alert)
        }
        #expect(cancellation is CancellationError)
    }

    @Test
    func authorizationPreservesBridgedAndNestedCancellationButBoundsNonCancellationChains() async {
        let bridgedCancellation = NSError(domain: "Swift.CancellationError", code: 1)
        let nestedCancellation = NSError(
            domain: "OuterAuthorization",
            code: 52,
            userInfo: [NSUnderlyingErrorKey: bridgedCancellation]
        )
        let bridgedService = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(
                authorizationResult: .failure(bridgedCancellation)
            )
        )
        let nestedService = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(
                authorizationResult: .failure(nestedCancellation)
            )
        )

        #expect(await capturedError {
            _ = try await bridgedService.requestAuthorization(.alert)
        } is CancellationError)
        #expect(await capturedError {
            _ = try await nestedService.requestAuthorization(.alert)
        } is CancellationError)

        let deep = deepNSErrorChain(
            depth: 40,
            outerDomain: "OuterPrivateAuthorization",
            outerCode: 91,
            leaf: NSError(domain: "Swift.CancellationError", code: 1)
        )
        let deepService = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(
                authorizationResult: .failure(deep)
            )
        )
        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .authorization,
                domain: "OuterPrivateAuthorization",
                code: 91
            )
        ) {
            _ = try await deepService.requestAuthorization(.alert)
        }

        let cyclic = CyclicTestNSError()
        let cyclicService = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(
                authorizationResult: .failure(cyclic)
            )
        )
        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .authorization,
                domain: "CyclicAuthorization",
                code: 92
            )
        ) {
            _ = try await cyclicService.requestAuthorization(.alert)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func authorizationReturnsTheStartedSystemOutcomeAfterTaskCancellation() async throws {
        let barrier = AsyncTestBarrier()
        let client = ScriptedLocalNotificationCenterClient(
            authorizationHandler: { _ in
                await barrier.arriveAndWait()
                return false
            }
        )
        let service = LocalNotificationService.fixture(client: client)
        let task = Task { try await service.requestAuthorization(.alert) }

        await barrier.waitUntilArrived()
        task.cancel()
        await barrier.release()

        #expect(try await task.value == false)
    }

    @Test
    func categoryValidationAndDeepLinkPolicyAreAtomicBeforeTheSystemCall() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)
        let original = try LocalNotificationFixtures.category(id: "original")
        let replacement = try LocalNotificationFixtures.category(id: "replacement")
        let rejected = try category(
            id: "rejected",
            actionID: "open",
            deepLink: URL(string: "https://private.invalid/route")!
        )

        try await service.setCategories([original])
        await #expect(throws: LocalNotificationServiceError.invalidCategory(.duplicateCategoryID)) {
            try await service.setCategories([replacement, replacement])
        }
        await #expect(throws: LocalNotificationServiceError.invalidDeepLink) {
            try await service.setCategories([replacement, rejected])
        }

        #expect(await client.categoryReplacements().count == 1)
        try await service.schedule(try request(id: "kept", categoryID: original.id))
        await #expect(throws: LocalNotificationServiceError.invalidCategory(.unknownCategory)) {
            try await service.schedule(try request(id: "not-installed", categoryID: replacement.id))
        }
        #expect(await client.addedRequests().count == 1)
    }

    @Test
    func failedCategorySystemMutationPreservesTheLastRegisteredCatalog() async throws {
        let outcomes = ThrowOnInvocation(invocation: 2, error: NSError(domain: "CategoryCenter", code: 12))
        let client = ScriptedLocalNotificationCenterClient(
            categoryHandler: { _, _ in try await outcomes.call() }
        )
        let service = LocalNotificationService.fixture(client: client)
        let original = try LocalNotificationFixtures.category(id: "original")
        let replacement = try LocalNotificationFixtures.category(id: "replacement")

        try await service.setCategories([original])
        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .setCategories,
                domain: "CategoryCenter",
                code: 12
            )
        ) {
            try await service.setCategories([replacement])
        }

        try await service.schedule(try request(id: "old-route", categoryID: original.id))
        await #expect(throws: LocalNotificationServiceError.invalidCategory(.unknownCategory)) {
            try await service.schedule(try request(id: "new-route", categoryID: replacement.id))
        }
    }

    @Test
    func emptyStartupCategoryBootstrapIsIdempotentAfterSuccess() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)

        try await service.bootstrapCategoriesIfNeeded()
        try await service.bootstrapCategoriesIfNeeded()
        try await service.schedule(try LocalNotificationFixtures.request(id: "request"))

        let replacements = await client.categoryReplacements()
        #expect(replacements.count == 1)
        #expect(replacements.first?.prefix == "AppTemplate.LocalNotification.category.")
        #expect(replacements.first?.categories.isEmpty == true)
    }

    @Test
    func categoryBootstrapRetriesAfterFailure() async throws {
        let outcomes = ThrowOnInvocation(invocation: 1, error: NSError(domain: "BootstrapCenter", code: 8))
        let client = ScriptedLocalNotificationCenterClient(
            categoryHandler: { _, _ in try await outcomes.call() }
        )
        let startup = try LocalNotificationFixtures.category(id: "startup")
        let service = LocalNotificationService.fixture(client: client, startupCategories: [startup])

        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .setCategories,
                domain: "BootstrapCenter",
                code: 8
            )
        ) {
            try await service.bootstrapCategoriesIfNeeded()
        }
        try await service.bootstrapCategoriesIfNeeded()
        try await service.bootstrapCategoriesIfNeeded()

        #expect(await client.categoryReplacements().count == 2)
        try await service.schedule(try request(id: "startup-request", categoryID: startup.id))
    }

    @Test
    func schedulePerformsPureValidationBeforeBootstrap() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)
        let invalid = LocalNotificationRequest(
            id: try LocalNotificationID("invalid"),
            content: LocalNotificationContent(),
            trigger: .immediate
        )

        await #expect(throws: LocalNotificationServiceError.invalidContent(.notObservable)) {
            try await service.schedule(invalid)
        }
        #expect(await client.operations().isEmpty)
    }

    @Test
    func invalidRequestDeepLinkAndAttachmentOptionsPreventBootstrapAndAdd() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)
        let rejectedDeepLink = LocalNotificationRequest(
            id: try LocalNotificationID("rejected-deep-link"),
            content: LocalNotificationContent(
                body: "Body",
                deepLink: URL(string: "https://private.invalid/token")!
            ),
            trigger: .immediate
        )
        let invalidAttachmentID = try LocalNotificationAttachmentID("invalid-options")
        let invalidOptions = LocalNotificationRequest(
            id: try LocalNotificationID("invalid-attachment-options"),
            content: LocalNotificationContent(
                body: "Body",
                attachments: [
                    LocalNotificationAttachment(
                        id: invalidAttachmentID,
                        fileURL: URL(fileURLWithPath: "/private/source.png"),
                        options: .init(thumbnailTime: -.infinity)
                    )
                ]
            ),
            trigger: .immediate
        )

        await #expect(throws: LocalNotificationServiceError.invalidDeepLink) {
            try await service.schedule(rejectedDeepLink)
        }
        await #expect(
            throws: LocalNotificationServiceError.invalidAttachment(
                invalidAttachmentID,
                .invalidOptions
            )
        ) {
            try await service.schedule(invalidOptions)
        }
        #expect(await client.operations().isEmpty)
    }

    @Test
    func failedReplacementPreparationLeavesOldRequestUntouched() async throws {
        let client = ScriptedLocalNotificationCenterClient(
            pending: [try .fixture(logicalID: "same", body: "old")]
        )
        let service = LocalNotificationService.fixture(client: client)
        let invalid = try LocalNotificationFixtures.request(
            id: "same",
            attachmentURL: URL(string: "https://example.invalid/a.png")!
        )

        await #expect(throws: LocalNotificationServiceError.self) {
            try await service.schedule(invalid)
        }
        #expect(await client.addedRequests().isEmpty)
        #expect(await client.removedPendingIDs().isEmpty)
    }

    @Test
    func unknownCategoryUsesTheExactClosedErrorAfterBootstrap() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)
        let missing = try LocalNotificationCategoryID("missing")

        await #expect(throws: LocalNotificationServiceError.invalidCategory(.unknownCategory)) {
            try await service.schedule(try request(id: "request", categoryID: missing))
        }
        #expect(await client.categoryReplacements().count == 1)
        #expect(await client.addedRequests().isEmpty)
    }

    @Test
    func envelopeEncodingFailureDoesNotStageOrAdd() async throws {
        let fixture = try AttachmentFixture()
        defer { fixture.cleanup() }
        let expected = LocalNotificationServiceError.invalidMetadata
        let codec = LocalNotificationServiceEnvelopeCodec(
            encode: { _ in throw expected },
            decodeManaged: LocalNotificationServiceEnvelopeCodec.live.decodeManaged
        )
        let service = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(),
            envelopeCodec: codec,
            stagingRoot: fixture.stagingRoot
        )
        let request = try fixture.request(id: "encode-failure")

        await #expect(throws: expected) {
            try await service.schedule(request)
        }
        #expect(try fixture.stagingItems().isEmpty)
    }

    @Test
    func successfulScheduleBuildsOneImmutableOwnedRequestAndCleansStaging() async throws {
        let fixture = try AttachmentFixture()
        defer { fixture.cleanup() }
        let client = ScriptedLocalNotificationCenterClient()
        let category = try routedCategory()
        let service = LocalNotificationService.fixture(
            client: client,
            startupCategories: [category],
            stagingRoot: fixture.stagingRoot
        )
        let deepLink = URL(string: "apptemplate://projects/project/fixture")!
        let request = try fixture.request(
            id: "scheduled",
            sound: .named(resourceName: "reminder.aiff"),
            categoryID: category.id,
            metadata: ["priority": .integer(3)],
            deepLink: deepLink
        )

        try await service.schedule(request)

        let added = try #require(await client.addedRequests().first)
        #expect(await client.addedRequests().count == 1)
        #expect(await client.removedPendingIDs().isEmpty)
        #expect(added.identifier == "AppTemplate.LocalNotification.request.c2NoZWR1bGVk")
        #expect(added.content.body == "Body")
        #expect(added.content.sound == .named(resourceName: "reminder.aiff"))
        #expect(added.content.categoryIdentifier == "AppTemplate.LocalNotification.category.Y2F0ZWdvcnk")
        #expect(added.content.attachments.count == 1)
        #expect(added.content.attachments.first?.identifier == "AppTemplate.LocalNotification.attachment.c2NoZWR1bGVk.aW1hZ2U")
        #expect(added.content.attachments.first?.fileURL != fixture.sourceURL)
        #expect(added.content.attachments.first?.fileURL.path.contains(fixture.sourceURL.lastPathComponent) == false)
        #expect(FileManager.default.fileExists(atPath: fixture.sourceURL.path))
        #expect(try fixture.stagingItems().isEmpty)

        let envelopeData = try #require(added.content.envelopeData)
        guard case let .v1(envelope) = try LocalNotificationEnvelopeCodec.decode(envelopeData) else {
            Issue.record("Expected a version-one envelope")
            return
        }
        #expect(envelope.requestID == request.id)
        #expect(envelope.sound == .named(resourceName: "reminder.aiff"))
        #expect(envelope.metadata == ["priority": .integer(3)])
        #expect(envelope.defaultDeepLink == deepLink)
        #expect(envelope.actionRoutes == [
            .button(id: try LocalNotificationActionID("open"), deepLink: deepLink),
            .textInput(id: try LocalNotificationActionID("reply"), deepLink: deepLink)
        ])
        #expect(!String(decoding: envelopeData, as: UTF8.self).contains(fixture.sourceURL.path))
    }

    @Test
    func addFailureIsRedactedAndCleansEveryStagedArtifact() async throws {
        let fixture = try AttachmentFixture()
        defer { fixture.cleanup() }
        let error = NSError(
            domain: "NotificationSchedule",
            code: 73,
            userInfo: [NSLocalizedDescriptionKey: fixture.sourceURL.path]
        )
        let client = ScriptedLocalNotificationCenterClient(addError: error)
        let service = LocalNotificationService.fixture(
            client: client,
            stagingRoot: fixture.stagingRoot
        )

        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .schedule,
                domain: "NotificationSchedule",
                code: 73
            )
        ) {
            try await service.schedule(try fixture.request(id: "failure"))
        }
        #expect(await client.addedRequests().count == 1)
        #expect(try fixture.stagingItems().isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellationAfterStagingCleansAndPreventsAdd() async throws {
        let fixture = try AttachmentFixture()
        defer { fixture.cleanup() }
        let barrier = AsyncTestBarrier()
        let stager = LocalNotificationServiceAttachmentStager(
            stage: { attachments, requestID in
                let staged = try LocalNotificationAttachmentStager.temporary(
                    root: fixture.stagingRoot
                ).stage(attachments, requestID: requestID)
                await barrier.arriveAndWait()
                return staged
            },
            cleanup: { staged in
                _ = LocalNotificationAttachmentStager.live().cleanup(staged)
            }
        )
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client, stager: stager)
        let task = Task { try await service.schedule(try fixture.request(id: "cancelled")) }

        await barrier.waitUntilArrived()
        task.cancel()
        await barrier.release()

        #expect(await capturedError { try await task.value } is CancellationError)
        #expect(await client.addedRequests().isEmpty)
        #expect(try fixture.stagingItems().isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellationAfterAddBeginsReturnsTheActualOutcomeAndCleans() async throws {
        let fixture = try AttachmentFixture()
        defer { fixture.cleanup() }
        let barrier = AsyncTestBarrier()
        let client = ScriptedLocalNotificationCenterClient(
            addHandler: { _ in await barrier.arriveAndWait() }
        )
        let service = LocalNotificationService.fixture(
            client: client,
            stagingRoot: fixture.stagingRoot
        )
        let task = Task { try await service.schedule(try fixture.request(id: "started")) }

        await barrier.waitUntilArrived()
        task.cancel()
        await barrier.release()

        try await task.value
        #expect(await client.addedRequests().count == 1)
        #expect(try fixture.stagingItems().isEmpty)
    }

    @Test
    func sameIdentifierUsesExactlyOneAddAndNeverPreRemoves() async throws {
        let client = ScriptedLocalNotificationCenterClient(
            pending: [try .fixture(logicalID: "same", body: "old")]
        )
        let service = LocalNotificationService.fixture(client: client)

        try await service.schedule(try LocalNotificationFixtures.request(id: "same", body: "new"))

        #expect(await client.addedRequests().count == 1)
        #expect(await client.removedPendingIDs().isEmpty)
    }

    @Test
    func pendingFiltersStrictOwnershipMapsUnreadableReasonsAndSortsDeterministically() async throws {
        let namespace = try LocalNotificationNamespace()
        let earlier = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        let validID = try LocalNotificationID("valid")
        let systemURL = URL(fileURLWithPath: "/system-owned/attachment.png")
        let validEnvelope = LocalNotificationEnvelopeV1(
            requestID: validID,
            categoryID: try LocalNotificationCategoryID("envelope-category"),
            sound: .named(resourceName: "trusted.aiff"),
            metadata: ["origin": .string("envelope")],
            defaultDeepLink: URL(string: "apptemplate://home")!,
            foregroundPresentation: [.banner],
            actionRoutes: []
        )
        let valid = systemRequest(
            identifier: namespace.physicalRequestID(validID),
            title: "system title",
            subtitle: "system subtitle",
            body: "system body",
            badge: 7,
            systemSound: .default,
            categoryIdentifier: namespace.physicalCategoryID(
                try LocalNotificationCategoryID("system-category")
            ),
            threadIdentifier: "system-thread",
            targetContentIdentifier: "system-target",
            summaryArgument: "system-summary",
            summaryArgumentCount: 4,
            relevanceScore: 0.75,
            interruptionLevel: .passive,
            envelopeData: try LocalNotificationEnvelopeCodec.encode(validEnvelope),
            trigger: .timeInterval(seconds: 90, repeats: false),
            nextTriggerDate: earlier,
            attachments: [
                LocalNotificationSystemAttachment(
                    identifier: namespace.physicalAttachmentID(
                        request: validID,
                        attachment: try LocalNotificationAttachmentID("observed")
                    ),
                    fileURL: systemURL,
                    typeIdentifier: "public.png"
                ),
                LocalNotificationSystemAttachment(
                    identifier: "foreign-attachment",
                    fileURL: URL(fileURLWithPath: "/private/source.png"),
                    typeIdentifier: "public.png"
                ),
                LocalNotificationSystemAttachment(
                    identifier: namespace.physicalAttachmentID(
                        request: try LocalNotificationID("wrong-request"),
                        attachment: try LocalNotificationAttachmentID("wrong")
                    ),
                    fileURL: URL(fileURLWithPath: "/system-owned/wrong.png"),
                    typeIdentifier: "public.png"
                ),
                LocalNotificationSystemAttachment(
                    identifier: namespace.physicalAttachmentID(
                        request: validID,
                        attachment: try LocalNotificationAttachmentID("missing-type")
                    ),
                    fileURL: URL(fileURLWithPath: "/system-owned/missing-type"),
                    typeIdentifier: nil
                )
            ]
        )
        let missing = systemRequest(
            identifier: namespace.physicalRequestID(try LocalNotificationID("missing")),
            envelopeData: nil,
            nextTriggerDate: later
        )
        let corrupt = systemRequest(
            identifier: namespace.physicalRequestID(try LocalNotificationID("corrupt")),
            envelopeData: Data("not-json".utf8),
            nextTriggerDate: later
        )
        let future = systemRequest(
            identifier: namespace.physicalRequestID(try LocalNotificationID("future")),
            envelopeData: Data(#"{"schemaVersion":99}"#.utf8),
            nextTriggerDate: nil
        )
        let mismatchEnvelope = LocalNotificationEnvelopeV1.serviceFixture(
            requestID: try LocalNotificationID("different")
        )
        let mismatch = systemRequest(
            identifier: namespace.physicalRequestID(try LocalNotificationID("mismatch")),
            envelopeData: try LocalNotificationEnvelopeCodec.encode(mismatchEnvelope),
            nextTriggerDate: nil
        )
        let foreign = systemRequest(identifier: "remote.request", envelopeData: nil)
        let noncanonical = systemRequest(
            identifier: "AppTemplate.LocalNotification.request.dmFsaWQ=",
            envelopeData: nil
        )
        let client = ScriptedLocalNotificationCenterClient(
            pending: [future, foreign, mismatch, corrupt, valid, noncanonical, missing]
        )
        let service = LocalNotificationService.fixture(client: client)

        let snapshots = await service.pending()

        #expect(snapshots.map(\.id.value) == ["valid", "corrupt", "missing", "future", "mismatch"])
        #expect(snapshots.map(\.payload) == [
            .decoded(
                LocalNotificationStoredRequest(
                    id: validID,
                    content: LocalNotificationStoredContent(
                        title: "system title",
                        subtitle: "system subtitle",
                        body: "system body",
                        badge: 7,
                        sound: .named(resourceName: "trusted.aiff"),
                        categoryID: try LocalNotificationCategoryID("system-category"),
                        threadIdentifier: "system-thread",
                        targetContentIdentifier: "system-target",
                        summaryArgument: "system-summary",
                        summaryArgumentCount: 4,
                        relevanceScore: 0.75,
                        interruptionLevel: .passive,
                        attachments: [
                            LocalNotificationStoredAttachment(
                                id: try LocalNotificationAttachmentID("observed"),
                                fileURL: systemURL,
                                typeIdentifier: "public.png"
                            )
                        ],
                        metadata: ["origin": .string("envelope")],
                        deepLink: URL(string: "apptemplate://home")!,
                        foregroundPresentation: [.banner]
                    ),
                    trigger: .timeInterval(seconds: 90, repeats: false)
                )
            ),
            .unreadable(.corruptEnvelope),
            .unreadable(.missingEnvelope),
            .unreadable(.unsupportedEnvelopeVersion),
            .unreadable(.identifierMismatch)
        ])
    }

    @Test
    func nonemptyForeignOrNoncanonicalSystemCategoryIsIdentifierMismatch() async throws {
        let namespace = try LocalNotificationNamespace()
        let foreignID = try LocalNotificationID("foreign-category")
        let noncanonicalID = try LocalNotificationID("noncanonical-category")
        let foreignEnvelope = LocalNotificationEnvelopeV1.serviceFixture(requestID: foreignID)
        let noncanonicalEnvelope = LocalNotificationEnvelopeV1.serviceFixture(requestID: noncanonicalID)
        let foreign = systemRequest(
            identifier: namespace.physicalRequestID(foreignID),
            categoryIdentifier: "remote.category",
            envelopeData: try LocalNotificationEnvelopeCodec.encode(foreignEnvelope)
        )
        let noncanonical = systemRequest(
            identifier: namespace.physicalRequestID(noncanonicalID),
            categoryIdentifier: "AppTemplate.LocalNotification.category.Y2F0ZWdvcnk=",
            envelopeData: try LocalNotificationEnvelopeCodec.encode(noncanonicalEnvelope)
        )
        let service = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(pending: [foreign, noncanonical])
        )

        #expect(await service.pending().map(\.payload) == [
            .unreadable(.identifierMismatch),
            .unreadable(.identifierMismatch)
        ])
    }

    @Test
    func validOwnedSystemCategoryOverridesEnvelopeCategoryAndRemainsReadable() async throws {
        let namespace = try LocalNotificationNamespace()
        let requestID = try LocalNotificationID("category-truth")
        let envelope = LocalNotificationEnvelopeV1(
            requestID: requestID,
            categoryID: try LocalNotificationCategoryID("envelope-category"),
            sound: .none,
            metadata: [:],
            defaultDeepLink: nil,
            foregroundPresentation: [],
            actionRoutes: []
        )
        let request = systemRequest(
            identifier: namespace.physicalRequestID(requestID),
            categoryIdentifier: namespace.physicalCategoryID(
                try LocalNotificationCategoryID("system-category")
            ),
            envelopeData: try LocalNotificationEnvelopeCodec.encode(envelope)
        )
        let service = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(pending: [request])
        )

        guard case let .decoded(stored)? = await service.pending().first?.payload else {
            Issue.record("Expected a readable managed snapshot")
            return
        }
        let expectedCategoryID = try LocalNotificationCategoryID("system-category")
        #expect(stored.content.categoryID == expectedCategoryID)
    }

    @Test
    func deliveredFiltersOwnershipAndSortsNewestThenIdentifier() async throws {
        let a = try LocalNotificationSystemRequest.fixture(logicalID: "a")
        let b = try LocalNotificationSystemRequest.fixture(logicalID: "b")
        let newest = try LocalNotificationSystemRequest.fixture(logicalID: "newest")
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_800_000_000)
        let foreign = systemRequest(identifier: "remote", envelopeData: nil)
        let client = ScriptedLocalNotificationCenterClient(
            delivered: [
                LocalNotificationSystemDelivered(request: b, deliveredAt: olderDate),
                LocalNotificationSystemDelivered(request: foreign, deliveredAt: .distantFuture),
                LocalNotificationSystemDelivered(request: newest, deliveredAt: newerDate),
                LocalNotificationSystemDelivered(request: a, deliveredAt: olderDate)
            ]
        )
        let service = LocalNotificationService.fixture(client: client)

        #expect(await service.delivered().map(\.id.value) == ["newest", "a", "b"])
    }

    @Test
    func policyRejectedManagedEnvelopeBecomesCorruptWithoutFailingTheList() async throws {
        let id = try LocalNotificationID("rejected")
        let envelope = LocalNotificationEnvelopeV1.serviceFixture(
            requestID: id,
            deepLink: URL(string: "https://private.invalid/token")!
        )
        let request = systemRequest(
            identifier: try LocalNotificationNamespace().physicalRequestID(id),
            envelopeData: try LocalNotificationEnvelopeCodec.encode(envelope)
        )
        let service = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(pending: [request])
        )

        #expect(await service.pending().first?.payload == .unreadable(.corruptEnvelope))
    }

    @Test
    func pointRemovalsNamespaceLogicalIdentifiersDirectly() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)
        let first = try LocalNotificationID("first")
        let second = try LocalNotificationID("second")

        await service.removePending([first, second])
        await service.removeDelivered([second])

        #expect(await client.removedPendingIDs() == [[
            "AppTemplate.LocalNotification.request.Zmlyc3Q",
            "AppTemplate.LocalNotification.request.c2Vjb25k"
        ]])
        #expect(await client.removedDeliveredIDs() == [[
            "AppTemplate.LocalNotification.request.c2Vjb25k"
        ]])
    }

    @Test
    func removeAllUsesOnlyCanonicalOwnedIdentifiersEvenForCorruptPayloads() async throws {
        let namespace = try LocalNotificationNamespace()
        let owned = namespace.physicalRequestID(try LocalNotificationID("owned"))
        let corruptOwned = systemRequest(identifier: owned, envelopeData: Data("corrupt".utf8))
        let foreign = systemRequest(identifier: "remote", envelopeData: nil)
        let noncanonical = systemRequest(
            identifier: "AppTemplate.LocalNotification.request.b3duZWQ=",
            envelopeData: nil
        )
        let client = ScriptedLocalNotificationCenterClient(
            pending: [foreign, noncanonical, corruptOwned],
            delivered: [
                LocalNotificationSystemDelivered(request: foreign, deliveredAt: .distantPast),
                LocalNotificationSystemDelivered(request: corruptOwned, deliveredAt: .distantPast)
            ]
        )
        let service = LocalNotificationService.fixture(client: client)

        await service.removeAllPending()
        await service.removeAllDelivered()

        #expect(await client.removedPendingIDs() == [[owned]])
        #expect(await client.removedDeliveredIDs() == [[owned]])
    }

    @Test
    func badgeRejectsNegativeBeforeTheClientClearsWithZeroAndRedactsSystemErrors() async throws {
        let privateError = NSError(
            domain: "NotificationBadge",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "PRIVATE-BADGE-DESCRIPTION"]
        )
        let client = ScriptedLocalNotificationCenterClient(badgeError: privateError)
        let service = LocalNotificationService.fixture(client: client)

        await #expect(throws: LocalNotificationServiceError.invalidContent(.invalidBadge)) {
            try await service.setBadgeCount(-1)
        }
        #expect(await client.badgeCounts().isEmpty)
        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .setBadge,
                domain: "NotificationBadge",
                code: 6
            )
        ) {
            try await service.setBadgeCount(4)
        }

        let clearingClient = ScriptedLocalNotificationCenterClient()
        let clearingService = LocalNotificationService.fixture(client: clearingClient)
        try await clearingService.clearBadge()
        #expect(await clearingClient.badgeCounts() == [0])
    }

    @Test
    func badgePreservesSystemCancellation() async {
        let service = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(badgeError: CancellationError())
        )

        #expect(await capturedError { try await service.setBadgeCount(1) } is CancellationError)
    }

    @Test(.timeLimit(.minutes(1)))
    func eventsAreTheInjectedHubStream() async throws {
        let hub = LocalNotificationEventHub()
        let service = LocalNotificationService.fixture(
            client: ScriptedLocalNotificationCenterClient(),
            eventHub: hub
        )
        let stream = await service.events()
        let consumer = Task { await firstEvent(in: stream) }
        let expected = try LocalNotificationFixtures.diagnostic(.missingEnvelope)

        await hub.publish(expected)

        #expect(await consumer.value == expected)
    }

    @Test
    func preCancelledFallibleOperationsNeverReachTheClient() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)

        let authorization = await preCancelledError {
            _ = try await service.requestAuthorization([])
        }
        let categories = await preCancelledError {
            let duplicate = try LocalNotificationFixtures.category(id: "duplicate")
            try await service.setCategories([duplicate, duplicate])
        }
        let schedule = await preCancelledError {
            try await service.schedule(
                LocalNotificationRequest(
                    id: try LocalNotificationID("invalid"),
                    content: LocalNotificationContent(),
                    trigger: .immediate
                )
            )
        }
        let badge = await preCancelledError {
            try await service.setBadgeCount(-1)
        }

        #expect(authorization is CancellationError)
        #expect(categories is CancellationError)
        #expect(schedule is CancellationError)
        #expect(badge is CancellationError)
        #expect(await client.operations().isEmpty)
    }

    @Test
    func alreadyBootstrappedPreCancelledBootstrapAndScheduleRemainCancellation() async throws {
        let client = ScriptedLocalNotificationCenterClient()
        let service = LocalNotificationService.fixture(client: client)
        try await service.bootstrapCategoriesIfNeeded()

        let bootstrap = await preCancelledError {
            try await service.bootstrapCategoriesIfNeeded()
        }
        let schedule = await preCancelledError {
            try await service.schedule(try LocalNotificationFixtures.request(id: "cancelled"))
        }

        #expect(bootstrap is CancellationError)
        #expect(schedule is CancellationError)
        #expect(await client.categoryReplacements().count == 1)
        #expect(await client.addedRequests().isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledQueuedCatalogOperationDoesNotReleaseOwnerAndLaterOperationProgresses() async throws {
        let barrier = AsyncTestBarrier()
        let enrollment = AsyncTestCounter()
        let client = ScriptedLocalNotificationCenterClient(
            categoryHandler: { _, categories in
                if categories.first?.identifier == "AppTemplate.LocalNotification.category.Zmlyc3Q" {
                    await barrier.arriveAndWait()
                }
            }
        )
        let service = LocalNotificationService.fixture(
            client: client,
            operationGateWaiterDidEnqueue: {
                Task { await enrollment.record() }
            }
        )
        let firstCategory = try LocalNotificationFixtures.category(id: "first")
        let cancelledCategory = try LocalNotificationFixtures.category(id: "cancelled")
        let thirdCategory = try LocalNotificationFixtures.category(id: "third")
        let first = Task { try await service.setCategories([firstCategory]) }

        await barrier.waitUntilArrived()
        let queued = Task { try await service.setCategories([cancelledCategory]) }
        await enrollment.waitUntilCount(1)
        queued.cancel()

        #expect(await capturedError { try await queued.value } is CancellationError)
        #expect(await client.categoryReplacements().count == 1)
        let third = Task {
            try await service.setCategories([thirdCategory])
        }
        await enrollment.waitUntilCount(2)
        #expect(await client.categoryReplacements().count == 1)
        await barrier.release()
        try await first.value
        try await third.value

        #expect(await client.categoryReplacements().map { $0.categories.first?.identifier } == [
            "AppTemplate.LocalNotification.category.Zmlyc3Q",
            "AppTemplate.LocalNotification.category.dGhpcmQ"
        ])
        try await service.schedule(try request(id: "third-request", categoryID: thirdCategory.id))
        await #expect(throws: LocalNotificationServiceError.invalidCategory(.unknownCategory)) {
            try await service.schedule(
                try request(id: "cancelled-request", categoryID: cancelledCategory.id)
            )
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func failedBootstrapUnblocksQueuedScheduleWhichRetriesBeforeAdding() async throws {
        let barrier = AsyncTestBarrier()
        let enrollment = AsyncTestCounter()
        let outcomes = ThrowOnInvocation(
            invocation: 1,
            error: NSError(domain: "BootstrapRace", code: 17)
        )
        let client = ScriptedLocalNotificationCenterClient(
            categoryHandler: { _, _ in
                await barrier.arriveAndWait()
                try await outcomes.call()
            }
        )
        let service = LocalNotificationService.fixture(
            client: client,
            operationGateWaiterDidEnqueue: {
                Task { await enrollment.record() }
            }
        )
        let first = Task { try await service.bootstrapCategoriesIfNeeded() }

        await barrier.waitUntilArrived()
        let schedule = Task {
            try await service.schedule(try LocalNotificationFixtures.request(id: "retry"))
        }
        await enrollment.waitUntilCount(1)
        await barrier.release()

        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .setCategories,
                domain: "BootstrapRace",
                code: 17
            )
        ) {
            try await first.value
        }
        try await schedule.value
        let operations = await client.operations()
        guard operations.count == 3,
              case let .replaceManagedCategories(_, firstCategories) = operations[0],
              case let .replaceManagedCategories(_, retryCategories) = operations[1],
              case let .add(added) = operations[2] else {
            Issue.record("Expected failed bootstrap, retry, then add")
            return
        }
        #expect(firstCategories.isEmpty)
        #expect(retryCategories.isEmpty)
        #expect(added.identifier == "AppTemplate.LocalNotification.request.cmV0cnk")
    }

    @Test(.timeLimit(.minutes(1)))
    func failedSetUnblocksQueuedScheduleWithoutPublishingTheStaleReplacement() async throws {
        let barrier = AsyncTestBarrier()
        let enrollment = AsyncTestCounter()
        let client = ScriptedLocalNotificationCenterClient(
            categoryHandler: { _, categories in
                guard categories.first?.identifier ==
                        "AppTemplate.LocalNotification.category.cmVwbGFjZW1lbnQ" else {
                    return
                }
                await barrier.arriveAndWait()
                throw NSError(domain: "SetRace", code: 23)
            }
        )
        let service = LocalNotificationService.fixture(
            client: client,
            operationGateWaiterDidEnqueue: {
                Task { await enrollment.record() }
            }
        )
        let original = try LocalNotificationFixtures.category(id: "original")
        let replacement = try LocalNotificationFixtures.category(id: "replacement")
        try await service.setCategories([original])
        let failedSet = Task { try await service.setCategories([replacement]) }

        await barrier.waitUntilArrived()
        let schedule = Task {
            try await service.schedule(try request(id: "old", categoryID: original.id))
        }
        await enrollment.waitUntilCount(1)
        await barrier.release()

        await #expect(
            throws: LocalNotificationServiceError.system(
                operation: .setCategories,
                domain: "SetRace",
                code: 23
            )
        ) {
            try await failedSet.value
        }
        try await schedule.value
        let operations = await client.operations()
        guard operations.count == 3,
              case let .replaceManagedCategories(_, originalCategories) = operations[0],
              case let .replaceManagedCategories(_, replacementCategories) = operations[1],
              case let .add(added) = operations[2] else {
            Issue.record("Expected original set, failed replacement, then old-catalog add")
            return
        }
        #expect(originalCategories.map(\.identifier) == [
            "AppTemplate.LocalNotification.category.b3JpZ2luYWw"
        ])
        #expect(replacementCategories.map(\.identifier) == [
            "AppTemplate.LocalNotification.category.cmVwbGFjZW1lbnQ"
        ])
        #expect(added.identifier == "AppTemplate.LocalNotification.request.b2xk")
        await #expect(throws: LocalNotificationServiceError.invalidCategory(.unknownCategory)) {
            try await service.schedule(
                try request(id: "new", categoryID: replacement.id)
            )
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func catalogMutationAndScheduleRemainOrderedAcrossSystemSuspension() async throws {
        let barrier = AsyncTestBarrier()
        let client = ScriptedLocalNotificationCenterClient(
            categoryHandler: { _, _ in await barrier.arriveAndWait() }
        )
        let service = LocalNotificationService.fixture(client: client)
        let category = try routedCategory()
        let categoryTask = Task { try await service.setCategories([category]) }

        await barrier.waitUntilArrived()
        let scheduleTask = Task {
            try await service.schedule(try request(id: "ordered", categoryID: category.id))
        }
        await barrier.release()

        try await categoryTask.value
        try await scheduleTask.value
        #expect(await client.categoryReplacements().count == 1)
        #expect(await client.addedRequests().count == 1)
    }
}

private extension LocalNotificationService {
    @MainActor
    static func fixture(
        client: any LocalNotificationCenterClient,
        startupCategories: [LocalNotificationCategory] = [],
        envelopeCodec: LocalNotificationServiceEnvelopeCodec = .live,
        stager: LocalNotificationServiceAttachmentStager? = nil,
        stagingRoot: URL? = nil,
        eventHub: LocalNotificationEventHub = LocalNotificationEventHub(),
        operationGateWaiterDidEnqueue: @escaping @Sendable () -> Void = {}
    ) -> LocalNotificationService {
        let root = stagingRoot ?? FileManager.default.temporaryDirectory.appending(
            path: "AppTemplate-LocalNotificationServiceTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try! FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let selectedStager = stager ?? LocalNotificationServiceAttachmentStager(
            stage: { attachments, requestID in
                try LocalNotificationAttachmentStager.temporary(root: root).stage(
                    attachments,
                    requestID: requestID
                )
            },
            cleanup: { staged in
                _ = LocalNotificationAttachmentStager.live().cleanup(staged)
            }
        )
        return LocalNotificationService(
            namespace: try! LocalNotificationNamespace("AppTemplate.LocalNotification"),
            validator: .live,
            deepLinkPolicy: LocalNotificationDeepLinkPolicy {
                $0.scheme?.lowercased() == "apptemplate"
            },
            envelopeCodec: envelopeCodec,
            stager: selectedStager,
            eventHub: eventHub,
            startupCategories: startupCategories,
            client: client,
            operationGateWaiterDidEnqueue: operationGateWaiterDidEnqueue
        )
    }
}

private nonisolated extension LocalNotificationSettings {
    static func serviceFixture(
        authorizationStatus: LocalNotificationAuthorizationStatus = .notDetermined
    ) -> Self {
        Self(
            authorizationStatus: authorizationStatus,
            alertSetting: .disabled,
            soundSetting: .disabled,
            badgeSetting: .disabled,
            notificationCenterSetting: .disabled,
            lockScreenSetting: .disabled,
            alertStyle: .none,
            previewSetting: .never
        )
    }
}

private nonisolated extension LocalNotificationEnvelopeV1 {
    static func serviceFixture(
        requestID: LocalNotificationID,
        deepLink: URL? = nil
    ) -> Self {
        Self(
            requestID: requestID,
            categoryID: nil,
            sound: .none,
            metadata: [:],
            defaultDeepLink: deepLink,
            foregroundPresentation: [],
            actionRoutes: []
        )
    }
}

private func request(
    id: String,
    categoryID: LocalNotificationCategoryID? = nil
) throws -> LocalNotificationRequest {
    LocalNotificationRequest(
        id: try LocalNotificationID(id),
        content: LocalNotificationContent(body: "Body", categoryID: categoryID),
        trigger: .immediate
    )
}

private func category(
    id: String,
    actionID: String,
    deepLink: URL
) throws -> LocalNotificationCategory {
    LocalNotificationCategory(
        id: try LocalNotificationCategoryID(id),
        actions: [
            .button(
                LocalNotificationButtonAction(
                    id: try LocalNotificationActionID(actionID),
                    title: "Open",
                    deepLink: deepLink
                )
            )
        ]
    )
}

private func routedCategory() throws -> LocalNotificationCategory {
    let deepLink = URL(string: "apptemplate://projects/project/fixture")!
    return LocalNotificationCategory(
        id: try LocalNotificationCategoryID("category"),
        actions: [
            .button(
                LocalNotificationButtonAction(
                    id: try LocalNotificationActionID("open"),
                    title: "Open",
                    deepLink: deepLink
                )
            ),
            .textInput(
                LocalNotificationTextInputAction(
                    id: try LocalNotificationActionID("reply"),
                    title: "Reply",
                    deepLink: deepLink,
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Message"
                )
            )
        ],
        hiddenPreviewsBodyPlaceholder: "Hidden",
        categorySummaryFormat: "%u more",
        hiddenPreviewsShowTitle: true,
        hiddenPreviewsShowSubtitle: true,
        reportsDismissal: true
    )
}

private func systemRequest(
    identifier: String,
    title: String = "",
    subtitle: String = "",
    body: String = "Body",
    badge: Int? = nil,
    systemSound: LocalNotificationSystemSound = .default,
    categoryIdentifier: String? = nil,
    threadIdentifier: String? = nil,
    targetContentIdentifier: String? = nil,
    summaryArgument: String? = nil,
    summaryArgumentCount: Int? = nil,
    relevanceScore: Double? = nil,
    interruptionLevel: LocalNotificationInterruptionLevel = .active,
    envelopeData: Data?,
    trigger: LocalNotificationSystemTrigger = .immediate,
    nextTriggerDate: Date? = nil,
    attachments: [LocalNotificationSystemAttachment] = []
) -> LocalNotificationSystemRequest {
    LocalNotificationSystemRequest(
        identifier: identifier,
        content: LocalNotificationSystemContent(
            title: title,
            subtitle: subtitle,
            body: body,
            badge: badge,
            sound: systemSound,
            categoryIdentifier: categoryIdentifier,
            threadIdentifier: threadIdentifier,
            targetContentIdentifier: targetContentIdentifier,
            summaryArgument: summaryArgument,
            summaryArgumentCount: summaryArgumentCount,
            relevanceScore: relevanceScore,
            interruptionLevel: interruptionLevel,
            attachments: attachments,
            envelopeData: envelopeData
        ),
        trigger: trigger,
        nextTriggerDate: nextTriggerDate
    )
}

private func deepNSErrorChain(
    depth: Int,
    outerDomain: String,
    outerCode: Int,
    leaf: NSError
) -> NSError {
    precondition(depth > 0)
    var error = leaf
    for index in (1..<depth).reversed() {
        error = NSError(
            domain: "PrivateNested\(index)",
            code: index,
            userInfo: [NSUnderlyingErrorKey: error]
        )
    }
    return NSError(
        domain: outerDomain,
        code: outerCode,
        userInfo: [NSUnderlyingErrorKey: error]
    )
}

private nonisolated final class CyclicTestNSError: NSError, @unchecked Sendable {
    init() {
        super.init(domain: "CyclicAuthorization", code: 92, userInfo: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("CyclicTestNSError does not support coding")
    }

    override var userInfo: [String: Any] {
        [NSUnderlyingErrorKey: self]
    }
}

private actor AsyncTestBarrier {
    private var hasArrived = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var isReleased = false

    func arriveAndWait() async {
        hasArrived = true
        let waiters = arrivalWaiters
        arrivalWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilArrived() async {
        guard !hasArrived else { return }
        await withCheckedContinuation { continuation in
            arrivalWaiters.append(continuation)
        }
    }

    func release() {
        isReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}

private actor AsyncTestCounter {
    private struct Waiter {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var count = 0
    private var waiters: [Waiter] = []

    func record() {
        count += 1
        let ready = waiters.filter { $0.target <= count }
        waiters.removeAll { $0.target <= count }
        for waiter in ready { waiter.continuation.resume() }
    }

    func waitUntilCount(_ target: Int) async {
        guard count < target else { return }
        await withCheckedContinuation { continuation in
            waiters.append(Waiter(target: target, continuation: continuation))
        }
    }
}

private actor ThrowOnInvocation {
    private let invocation: Int
    private let error: any Error
    private var callCount = 0

    init(invocation: Int, error: any Error) {
        self.invocation = invocation
        self.error = error
    }

    func call() throws {
        callCount += 1
        if callCount == invocation { throw error }
    }
}

private struct AttachmentFixture {
    let root: URL
    let stagingRoot: URL
    let sourceURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "AppTemplate-LocalNotificationServiceAttachment-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        stagingRoot = root.appending(path: "staging", directoryHint: .isDirectory)
        let sourceDirectory = root.appending(path: "source", directoryHint: .isDirectory)
        sourceURL = sourceDirectory.appending(
            path: "PRIVATE-original-name.png",
            directoryHint: .notDirectory
        )
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: sourceURL)
    }

    func request(
        id: String,
        sound: LocalNotificationSound = .none,
        categoryID: LocalNotificationCategoryID? = nil,
        metadata: [String: LocalNotificationMetadataValue] = [:],
        deepLink: URL? = nil
    ) throws -> LocalNotificationRequest {
        LocalNotificationRequest(
            id: try LocalNotificationID(id),
            content: LocalNotificationContent(
                body: "Body",
                sound: sound,
                categoryID: categoryID,
                attachments: [
                    LocalNotificationAttachment(
                        id: try LocalNotificationAttachmentID("image"),
                        fileURL: sourceURL,
                        options: .init(typeHint: "public.png")
                    )
                ],
                metadata: metadata,
                deepLink: deepLink
            ),
            trigger: .immediate
        )
    }

    func stagingItems() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: stagingRoot,
            includingPropertiesForKeys: nil
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func capturedError<T: Sendable>(
    _ operation: @escaping @Sendable () async throws -> T
) async -> (any Error)? {
    do {
        _ = try await operation()
        return nil
    } catch {
        return error
    }
}

private func preCancelledError(
    _ operation: @escaping @Sendable () async throws -> Void
) async -> (any Error)? {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await operation()
    }
    return await capturedError { try await task.value }
}

private func firstEvent(
    in stream: AsyncStream<LocalNotificationEvent>
) async -> LocalNotificationEvent? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}
