import Testing
@testable import AppTemplate

struct UITestScriptConsumptionTrackerTests {
    @Test
    func onlySharedZeroStatePublishesExhaustedAndReplayIsImmediate() async throws {
        let tracker = UITestScriptConsumptionTracker(networkSteps: 1, imageSteps: 1)
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .pending)
        await tracker.didConsume(.network)
        #expect(await iterator.next() == .pending)
        await tracker.didConsume(.image)
        #expect(await iterator.next() == .exhausted)
        var replay = await tracker.updates().makeAsyncIterator()
        #expect(await replay.next() == .exhausted)
    }

    @Test
    func failureIsTerminal() async {
        let tracker = UITestScriptConsumptionTracker(networkSteps: 1, imageSteps: 0)
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .pending)
        await tracker.didFail(.network)
        #expect(await iterator.next() == .failed)
        await tracker.didConsume(.network)
        #expect(await iterator.next() == .failed)
        var replay = await tracker.updates().makeAsyncIterator()
        #expect(await replay.next() == .failed)
    }

    @Test
    func emptySharedScriptStartsExhausted() async {
        let tracker = UITestScriptConsumptionTracker(networkSteps: 0, imageSteps: 0)
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .exhausted)
    }

    @Test
    func notificationStepsParticipateInTheSharedTerminalState() async {
        let tracker = UITestScriptConsumptionTracker(
            networkSteps: 0,
            imageSteps: 0,
            notificationSteps: 2
        )
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .pending)
        await tracker.didConsume(.notification)
        #expect(await iterator.next() == .pending)
        await tracker.didConsume(.notification)
        #expect(await iterator.next() == .exhausted)
    }
}
