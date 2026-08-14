import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct LocalNotificationNavigationCoordinatorTests {
    @Test(.timeLimit(.minutes(1)))
    func lastEligibleSceneAloneReceivesTheRoute() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let first = SceneReceiverSpy()
        let second = SceneReceiverSpy()
        let firstID = sceneID(1)
        let secondID = sceneID(2)
        coordinator.register(id: firstID, receiver: first)
        coordinator.register(id: secondID, receiver: second)
        coordinator.setEligible(true, id: firstID)
        coordinator.setEligible(true, id: secondID)
        coordinator.start()

        await hub.publish(
            try openedEvent(
                id: "last-scene",
                url: "apptemplate://services"
            )
        )
        await second.waitForCount(1)

        #expect(first.urls.isEmpty)
        #expect(
            second.urls.map(\.absoluteString)
                == ["apptemplate://services"]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func repeatedEligibleTrueMakesThatSceneMostRecentAgain() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let first = SceneReceiverSpy()
        let second = SceneReceiverSpy()
        let firstID = sceneID(1)
        let secondID = sceneID(2)
        coordinator.register(id: firstID, receiver: first)
        coordinator.register(id: secondID, receiver: second)
        coordinator.setEligible(true, id: firstID)
        coordinator.setEligible(true, id: secondID)
        coordinator.setEligible(true, id: firstID)
        coordinator.start()

        await hub.publish(
            try openedEvent(
                id: "reactivated-scene",
                url: "apptemplate://services"
            )
        )
        await first.waitForCount(1)

        #expect(
            first.urls.map(\.absoluteString) == ["apptemplate://services"]
        )
        #expect(second.urls.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func replacingTheSameSceneIDResetsEligibilityUntilReactivated()
        async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let first = SceneReceiverSpy()
        let replacement = SceneReceiverSpy()
        let receiverID = sceneID(1)
        coordinator.register(id: receiverID, receiver: first)
        coordinator.setEligible(true, id: receiverID)
        coordinator.register(id: receiverID, receiver: replacement)
        coordinator.start()
        let events = await hub.events()
        let barrierID = try LocalNotificationID("replacement-barrier")
        let barrier = Task {
            await firstDiagnostic(id: barrierID, in: events)
        }

        await hub.publish(
            try openedEvent(
                id: "replacement-route",
                url: "apptemplate://services"
            )
        )
        await hub.publish(
            try openedEvent(
                id: barrierID.value,
                url: "https://private.example.invalid/replacement-barrier"
            )
        )
        #expect(await barrier.value?.reason == .invalidDeepLink)
        #expect(first.urls.isEmpty)
        #expect(replacement.urls.isEmpty)

        coordinator.setEligible(true, id: receiverID)
        await replacement.waitForCount(1)

        #expect(first.urls.isEmpty)
        #expect(
            replacement.urls.map(\.absoluteString)
                == ["apptemplate://services"]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func resignAndUnregisterFallBackToTheNextNewestScene() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let first = SceneReceiverSpy()
        let second = SceneReceiverSpy()
        let firstID = sceneID(1)
        let secondID = sceneID(2)
        coordinator.register(id: firstID, receiver: first)
        coordinator.register(id: secondID, receiver: second)
        coordinator.setEligible(true, id: firstID)
        coordinator.setEligible(true, id: secondID)
        coordinator.start()

        coordinator.setEligible(false, id: secondID)
        await hub.publish(
            try openedEvent(
                id: "after-resign",
                url: "apptemplate://store"
            )
        )
        await first.waitForCount(1)

        coordinator.setEligible(true, id: secondID)
        coordinator.unregister(id: secondID)
        coordinator.unregister(id: secondID)
        await hub.publish(
            try openedEvent(
                id: "after-unregister",
                url: "apptemplate://services"
            )
        )
        await first.waitForCount(2)

        #expect(
            first.urls.map(\.absoluteString) == [
                "apptemplate://store",
                "apptemplate://services"
            ]
        )
        #expect(second.urls.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func deallocatedNewestReceiverIsPrunedAndFallsBack() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let fallback = SceneReceiverSpy()
        var newest: SceneReceiverSpy? = SceneReceiverSpy()
        weak let weakNewest = newest
        let fallbackID = sceneID(1)
        let newestID = sceneID(2)
        coordinator.register(id: fallbackID, receiver: fallback)
        coordinator.register(
            id: newestID,
            receiver: try #require(newest)
        )
        coordinator.setEligible(true, id: fallbackID)
        coordinator.setEligible(true, id: newestID)
        coordinator.start()

        newest = nil
        #expect(weakNewest == nil)
        coordinator.setEligible(true, id: newestID)
        await hub.publish(
            try openedEvent(
                id: "weak-fallback",
                url: "apptemplate://services"
            )
        )
        await fallback.waitForCount(1)

        #expect(
            fallback.urls.map(\.absoluteString)
                == ["apptemplate://services"]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func noEligibleSceneBuffersMultipleURLsAndDrainsOnceInOrder() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let receiver = SceneReceiverSpy()
        let receiverID = sceneID(1)
        coordinator.register(id: receiverID, receiver: receiver)
        coordinator.start()
        let events = await hub.events()
        let barrierID = try LocalNotificationID("fifo-barrier")
        let barrier = Task {
            await firstDiagnostic(id: barrierID, in: events)
        }

        for (id, url) in [
            ("fifo-product", "apptemplate://store/product/17"),
            ("fifo-service", "apptemplate://services/keychain"),
            ("fifo-profile", "apptemplate://store/profile")
        ] {
            await hub.publish(try openedEvent(id: id, url: url))
        }
        await hub.publish(
            try openedEvent(
                id: barrierID.value,
                url: "https://private.example.invalid/secret"
            )
        )
        #expect(await barrier.value?.reason == .invalidDeepLink)
        #expect(receiver.urls.isEmpty)

        var didReenter = false
        receiver.onReceive = { [weak coordinator] _ in
            guard !didReenter else { return }
            didReenter = true
            coordinator?.setEligible(true, id: receiverID)
        }
        coordinator.setEligible(true, id: receiverID)
        await receiver.waitForCount(3)

        #expect(
            receiver.urls.map(\.absoluteString) == [
                "apptemplate://store/product/17",
                "apptemplate://services/keychain",
                "apptemplate://store/profile"
            ]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func eventsPublishedBeforeStartSurviveRepeatedStartInFIFOOrder() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let receiver = SceneReceiverSpy()
        let receiverID = sceneID(1)
        coordinator.register(id: receiverID, receiver: receiver)
        coordinator.setEligible(true, id: receiverID)

        await hub.publish(
            try openedEvent(
                id: "before-start-home",
                url: "apptemplate://store"
            )
        )
        await hub.publish(
            try openedEvent(
                id: "before-start-settings",
                url: "apptemplate://services"
            )
        )
        coordinator.start()
        coordinator.start()
        await receiver.waitForCount(2)

        #expect(
            receiver.urls.map(\.absoluteString) == [
                "apptemplate://store",
                "apptemplate://services"
            ]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func openedActionAndTextActionDeliverOnlyTheirValidURLs() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let receiver = SceneReceiverSpy()
        let receiverID = sceneID(1)
        let notification = try notification(id: "route-kinds")
        coordinator.register(id: receiverID, receiver: receiver)
        coordinator.setEligible(true, id: receiverID)
        coordinator.start()

        await hub.publish(
            .opened(
                notification: notification,
                deepLink: URL(string: "apptemplate://store")
            )
        )
        await hub.publish(
            .action(
                notification: notification,
                id: try LocalNotificationActionID("open-settings"),
                deepLink: URL(string: "apptemplate://services")
            )
        )
        await hub.publish(
            .textAction(
                notification: notification,
                id: try LocalNotificationActionID("reply"),
                text: "private response",
                deepLink: URL(string: "apptemplate://services")
            )
        )
        await receiver.waitForCount(3)

        #expect(
            receiver.urls.map(\.absoluteString) == [
                "apptemplate://store",
                "apptemplate://services",
                "apptemplate://services"
            ]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func nonRouteEventsAndNilDeepLinksNeverReachAReceiver() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let receiver = SceneReceiverSpy()
        let receiverID = sceneID(1)
        let notification = try notification(id: "no-routes")
        coordinator.register(id: receiverID, receiver: receiver)
        coordinator.setEligible(true, id: receiverID)
        coordinator.start()
        let events = await hub.events()
        let barrierID = try LocalNotificationID("non-route-barrier")
        let barrier = Task {
            await firstDiagnostic(id: barrierID, in: events)
        }

        await hub.publish(
            .foreground(
                notification: notification,
                presentation: [.banner]
            )
        )
        await hub.publish(.dismissed(notification: notification))
        await hub.publish(
            .opened(notification: notification, deepLink: nil)
        )
        await hub.publish(
            .action(
                notification: notification,
                id: try LocalNotificationActionID("nil-action"),
                deepLink: nil
            )
        )
        await hub.publish(
            .textAction(
                notification: notification,
                id: try LocalNotificationActionID("nil-text-action"),
                text: "private response",
                deepLink: nil
            )
        )
        await hub.publish(
            try openedEvent(
                id: barrierID.value,
                url: "https://private.example.invalid/non-route-barrier"
            )
        )

        #expect(await barrier.value?.reason == .invalidDeepLink)
        #expect(receiver.urls.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func invalidURLsPublishOneRedactedDiagnosticAndNeverUseFallback() async throws {
        let hub = LocalNotificationEventHub()
        let coordinator = makeCoordinator(hub: hub)
        let router = AppRouter(
            appFlowRouter: AppFlowRouter(flow: .main),
            selectedSection: .services
        )
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        router.store.push(.cart)
        router.services.open(.appInfo)
        let snapshotBefore = lifecycle.snapshot
        let receiver = SceneReceiverSpy { url in
            _ = lifecycle.receive(url)
        }
        let receiverID = sceneID(1)
        coordinator.register(id: receiverID, receiver: receiver)
        coordinator.setEligible(true, id: receiverID)
        coordinator.start()
        let events = await hub.events()
        let rejectedID = try LocalNotificationID("invalid-route")
        let barrierID = try LocalNotificationID("invalid-route-barrier")
        let diagnosticsTask = Task {
            await collectDiagnostics(until: barrierID, in: events)
        }

        await hub.publish(
            try openedEvent(
                id: rejectedID.value,
                url: "https://private.example.invalid/notification/secret"
            )
        )
        await hub.publish(
            try openedEvent(
                id: barrierID.value,
                url: "apptemplate://unknown/private-secret"
            )
        )
        let observedDiagnostics = await diagnosticsTask.value

        #expect(
            observedDiagnostics == [
                LocalNotificationDiagnostic(
                    id: rejectedID,
                    reason: .invalidDeepLink
                ),
                LocalNotificationDiagnostic(
                    id: barrierID,
                    reason: .invalidDeepLink
                )
            ]
        )
        #expect(receiver.urls.isEmpty)
        #expect(lifecycle.snapshot == snapshotBefore)
    }

    @Test
    func startingTheCoordinatorDoesNotKeepItAlive() {
        let hub = LocalNotificationEventHub()
        weak var releasedCoordinator: LocalNotificationNavigationCoordinator?

        do {
            let coordinator = makeCoordinator(hub: hub)
            coordinator.start()
            coordinator.start()
            releasedCoordinator = coordinator
        }

        #expect(releasedCoordinator == nil)
    }

    private func makeCoordinator(
        hub: LocalNotificationEventHub
    ) -> LocalNotificationNavigationCoordinator {
        LocalNotificationNavigationCoordinator(
            eventHub: hub,
            parser: DeepLinkParser(scheme: "apptemplate")
        )
    }
}

@MainActor
private final class SceneReceiverSpy: LocalNotificationSceneReceiving {
    private(set) var urls: [URL] = []
    var onReceive: ((URL) -> Void)?

    private var waiters: [SceneReceiverCountWaiter] = []

    init(onReceive: ((URL) -> Void)? = nil) {
        self.onReceive = onReceive
    }

    func receiveLocalNotificationURL(_ url: URL) {
        urls.append(url)
        onReceive?(url)
        let satisfied = waiters.filter { urls.count >= $0.expectedCount }
        waiters.removeAll { urls.count >= $0.expectedCount }
        for waiter in satisfied { waiter.continuation.resume() }
    }

    func waitForCount(_ expectedCount: Int) async {
        guard urls.count < expectedCount else { return }
        await withCheckedContinuation { continuation in
            waiters.append(
                SceneReceiverCountWaiter(
                    expectedCount: expectedCount,
                    continuation: continuation
                )
            )
        }
    }
}

private nonisolated struct SceneReceiverCountWaiter: Sendable {
    let expectedCount: Int
    let continuation: CheckedContinuation<Void, Never>
}

private nonisolated func sceneID(_ suffix: Int) -> UUID {
    UUID(
        uuidString: String(
            format: "00000000-0000-0000-0000-%012d",
            suffix
        )
    )!
}

private nonisolated func openedEvent(
    id: String,
    url: String
) throws -> LocalNotificationEvent {
    .opened(
        notification: try notification(id: id),
        deepLink: URL(string: url)
    )
}

private nonisolated func notification(
    id: String
) throws -> LocalNotificationEventNotification {
    let logicalID = try LocalNotificationID(id)
    return LocalNotificationEventNotification(
        id: logicalID,
        payload: .decoded(
            LocalNotificationStoredRequest(
                id: logicalID,
                content: LocalNotificationStoredContent(body: "Body"),
                trigger: .immediate
            )
        )
    )
}

private nonisolated func firstDiagnostic(
    id: LocalNotificationID,
    in stream: AsyncStream<LocalNotificationEvent>
) async -> LocalNotificationDiagnostic? {
    for await event in stream {
        guard case let .diagnostic(diagnostic) = event,
              diagnostic.id == id else {
            continue
        }
        return diagnostic
    }
    return nil
}

private nonisolated func collectDiagnostics(
    until finalID: LocalNotificationID,
    in stream: AsyncStream<LocalNotificationEvent>
) async -> [LocalNotificationDiagnostic] {
    var result: [LocalNotificationDiagnostic] = []
    for await event in stream {
        guard case let .diagnostic(diagnostic) = event else { continue }
        result.append(diagnostic)
        if diagnostic.id == finalID { return result }
    }
    return result
}
