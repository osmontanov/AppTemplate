import Foundation
import Testing
@testable import AppTemplate

nonisolated
struct LocalNotificationEventHubTests {
    @Test(.timeLimit(.minutes(1)))
    func twoSubscribersReceiveTheSameEventsInOrder() async throws {
        let hub = LocalNotificationEventHub()
        let first = await hub.events()
        let second = await hub.events()
        let expected = try LocalNotificationFixtures.threeDiagnostics()

        let firstTask = Task { await collect(first, count: expected.count) }
        let secondTask = Task { await collect(second, count: expected.count) }
        for event in expected { await hub.publish(event) }

        #expect(await firstTask.value == expected)
        #expect(await secondTask.value == expected)
    }

    @Test(.timeLimit(.minutes(1)))
    func navigationEventsBufferRouteEventsPublishedBeforeIteration() async throws {
        let hub = LocalNotificationEventHub()
        let expected = try routeEvents()

        for event in expected { await hub.publish(event) }

        #expect(await collect(hub.navigationEvents, count: expected.count) == expected)
    }

    @Test(.timeLimit(.minutes(1)))
    func navigationEventsReceiveOnlyRoutesInOrderWhenIterationStartsFirst() async throws {
        let hub = LocalNotificationEventHub()
        let iteration = EventIterationProbe()
        let expected = try routeEvents()
        let events = try interleavedNavigationAndNonNavigationEvents()
        let consumer = Task {
            var iterator = hub.navigationEvents.makeAsyncIterator()
            await iteration.markStarted()
            var received: [LocalNotificationEvent] = []
            while received.count < expected.count, let event = await iterator.next() {
                received.append(event)
            }
            return received
        }

        await iteration.waitUntilStarted()
        for event in events { await hub.publish(event) }

        #expect(await consumer.value == expected)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingOneSubscriberRemovesOnlyItsContinuation() async throws {
        let hub = LocalNotificationEventHub()
        let cancelledStream = await hub.events()
        let remainingStream = await hub.events()
        let iteration = EventIterationProbe()
        let cancelledConsumer = Task {
            var iterator = cancelledStream.makeAsyncIterator()
            await iteration.markStarted()
            return await iterator.next()
        }

        await iteration.waitUntilStarted()
        cancelledConsumer.cancel()
        #expect(await cancelledConsumer.value == nil)
        await hub.waitUntilSubscriptionCountForTesting(1)

        let expected = try LocalNotificationFixtures.diagnostic(.missingEnvelope)
        let remainingConsumer = Task {
            var iterator = remainingStream.makeAsyncIterator()
            return await iterator.next()
        }
        await hub.publish(expected)

        #expect(await remainingConsumer.value == expected)
        #expect(await hub.activeSubscriptionCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func lateSubscriberReceivesOnlyEventsPublishedAfterRegistration() async throws {
        let hub = LocalNotificationEventHub()
        let earlyStream = await hub.events()
        let beforeRegistration = try LocalNotificationFixtures.diagnostic(.missingEnvelope)
        let afterRegistration = try LocalNotificationFixtures.diagnostic(.corruptEnvelope)

        await hub.publish(beforeRegistration)
        let lateStream = await hub.events()
        let earlyConsumer = Task { await collect(earlyStream, count: 2) }
        let lateConsumer = Task { await collect(lateStream, count: 1) }
        await hub.publish(afterRegistration)

        #expect(await earlyConsumer.value == [beforeRegistration, afterRegistration])
        #expect(await lateConsumer.value == [afterRegistration])
    }

    @Test(.timeLimit(.minutes(1)))
    func liveSubscriberReceivesOneHundredEventsWithoutDrop() async throws {
        let hub = LocalNotificationEventHub()
        let stream = await hub.events()
        let expected = try (0..<100).map { index in
            LocalNotificationEvent.diagnostic(
                LocalNotificationDiagnostic(
                    id: try LocalNotificationID("request-\(index)"),
                    reason: .missingEnvelope
                )
            )
        }
        let consumer = Task { await collect(stream, count: expected.count) }

        for event in expected { await hub.publish(event) }

        #expect(await consumer.value == expected)
    }
}

private actor EventIterationProbe {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func markStarted() {
        started = true
        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters { waiter.resume() }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private nonisolated func collect(
    _ stream: AsyncStream<LocalNotificationEvent>,
    count: Int
) async -> [LocalNotificationEvent] {
    var events: [LocalNotificationEvent] = []
    for await event in stream.prefix(count) { events.append(event) }
    return events
}

private nonisolated func routeEvents() throws -> [LocalNotificationEvent] {
    let notification = try eventNotification()
    return [
        .opened(notification: notification, deepLink: URL(string: "app://opened")),
        .action(
            notification: notification,
            id: try LocalNotificationActionID("button"),
            deepLink: URL(string: "app://button")
        ),
        .textAction(
            notification: notification,
            id: try LocalNotificationActionID("reply"),
            text: "Reply text",
            deepLink: URL(string: "app://reply")
        )
    ]
}

private nonisolated func interleavedNavigationAndNonNavigationEvents() throws -> [LocalNotificationEvent] {
    let notification = try eventNotification()
    let routes = try routeEvents()
    return [
        .foreground(notification: notification, presentation: [.banner]),
        routes[0],
        .dismissed(notification: notification),
        .opened(notification: notification, deepLink: nil),
        routes[1],
        .action(
            notification: notification,
            id: try LocalNotificationActionID("no-route"),
            deepLink: nil
        ),
        .diagnostic(LocalNotificationDiagnostic(id: nil, reason: .invalidDeepLink)),
        routes[2]
    ]
}

private nonisolated func eventNotification() throws -> LocalNotificationEventNotification {
    let id = try LocalNotificationID("request")
    let request = LocalNotificationStoredRequest(
        id: id,
        content: LocalNotificationStoredContent(body: "Body"),
        trigger: .immediate
    )
    return LocalNotificationEventNotification(id: id, payload: .decoded(request))
}
