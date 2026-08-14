import Foundation
import Testing
@testable import AppTemplate

nonisolated
struct LocalNotificationEventHubTests {
    @Test(.timeLimit(.minutes(1)))
    func publishRecordsHistoryBeforeYieldingPublicEvent() async throws {
        let history = LocalNotificationEventHistory(clock: .live)
        let hub = LocalNotificationEventHub(history: history)
        let stream = await hub.events()
        let event = try LocalNotificationFixtures.diagnostic(.missingEnvelope)
        let observed = Task { () -> (LocalNotificationEvent?, Int) in
            var iterator = stream.makeAsyncIterator()
            let value = await iterator.next()
            return (value, await history.records().count)
        }

        await hub.publish(event)

        let result = await observed.value
        #expect(result.0 == event)
        #expect(result.1 == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func twoSubscribersReceiveTheSameEventsInOrder() async throws {
        let hub = makeLocalNotificationEventHub()
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
    func bufferingNewestHundredDropsOnlyTheOldestPublicEvent() async throws {
        let hub = makeLocalNotificationEventHub()
        let stream = await hub.events()
        let expected = try (1...101).map { index in
            LocalNotificationEvent.diagnostic(.init(
                id: try LocalNotificationID("request-\(index)"),
                reason: .missingEnvelope
            ))
        }
        for event in expected { await hub.publish(event) }

        #expect(await collect(stream, count: 100) == Array(expected.dropFirst()))
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellationRemovesOnlyTerminatedSubscriber() async throws {
        let hub = makeLocalNotificationEventHub()
        let cancelled = await hub.events()
        let remaining = await hub.events()
        let task = Task {
            var iterator = cancelled.makeAsyncIterator()
            return await iterator.next()
        }
        task.cancel()
        _ = await task.value
        await hub.waitUntilSubscriptionCountForTesting(1)

        let expected = try LocalNotificationFixtures.diagnostic(.corruptEnvelope)
        let receiver = Task {
            var iterator = remaining.makeAsyncIterator()
            return await iterator.next()
        }
        await hub.publish(expected)

        #expect(await receiver.value == expected)
    }
}

private nonisolated func collect(
    _ stream: AsyncStream<LocalNotificationEvent>,
    count: Int
) async -> [LocalNotificationEvent] {
    var values: [LocalNotificationEvent] = []
    for await event in stream.prefix(count) { values.append(event) }
    return values
}
