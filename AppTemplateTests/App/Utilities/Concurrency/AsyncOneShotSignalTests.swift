import Testing
@testable import AppTemplate

struct AsyncOneShotSignalTests {
    @Test func firstResolutionResumesExistingAndFutureWaitersWithSameValue() async {
        let signal = AsyncOneShotSignal<String>()
        let waiterStarted = TestLatch()

        let existingWaiter = Task {
            await waiterStarted.release()
            return await signal.wait()
        }
        await waiterStarted.wait()

        #expect(await signal.resolve("first"))
        #expect(await !signal.resolve("second"))
        #expect(await existingWaiter.value == "first")
        #expect(await signal.wait() == "first")
    }

    @Test func nilOptionalIsAResolvedValueRatherThanTheUnresolvedSentinel() async {
        let signal = AsyncOneShotSignal<Int?>()

        #expect(await signal.resolve(nil))
        #expect(await !signal.resolve(42))
        #expect(await signal.wait() == nil)
    }
}

private actor TestLatch {
    private var resolved = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !resolved else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        guard !resolved else { return }
        resolved = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}
