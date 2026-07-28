import Foundation
@testable import AppTemplate

nonisolated enum BrowseServiceTestError: Error {
    case failed
}

actor FailingBrowseService: IBrowseService {
    func items() throws -> [BrowseItem] {
        throw BrowseServiceTestError.failed
    }

    func item(id: BrowseItem.ID) throws -> BrowseItem? {
        throw BrowseServiceTestError.failed
    }
}

actor ControlledBrowseService: IBrowseService {
    private var listCount = 0
    private var detailCount = 0
    private var listContinuations:
        [Int: CheckedContinuation<[BrowseItem], any Error>] = [:]
    private var detailContinuations:
        [Int: CheckedContinuation<BrowseItem?, any Error>] = [:]
    private var listCancellations: [Int: Bool] = [:]
    private var detailCancellations: [Int: Bool] = [:]
    private var callWaiters: [CheckedContinuation<Void, Never>] = []

    func items() async throws -> [BrowseItem] {
        let index = listCount
        listCount += 1
        notifyCallWaiters()

        do {
            let items = try await withCheckedThrowingContinuation { continuation in
                listContinuations[index] = continuation
            }
            listCancellations[index] = Task.isCancelled
            return items
        } catch {
            listCancellations[index] = Task.isCancelled
            throw error
        }
    }

    func item(id: BrowseItem.ID) async throws -> BrowseItem? {
        let index = detailCount
        detailCount += 1
        notifyCallWaiters()

        do {
            let item = try await withCheckedThrowingContinuation { continuation in
                detailContinuations[index] = continuation
            }
            detailCancellations[index] = Task.isCancelled
            return item
        } catch {
            detailCancellations[index] = Task.isCancelled
            throw error
        }
    }

    func waitForCalls(lists: Int = 0, details: Int = 0) async {
        while listCount < lists || detailCount < details {
            await withCheckedContinuation { continuation in
                callWaiters.append(continuation)
            }
        }
    }

    func resumeItems(
        at index: Int,
        returning items: [BrowseItem]
    ) {
        listContinuations.removeValue(forKey: index)?.resume(
            returning: items
        )
    }

    func resumeItem(
        at index: Int,
        returning item: BrowseItem?
    ) {
        detailContinuations.removeValue(forKey: index)?.resume(
            returning: item
        )
    }

    func failItems(at index: Int) {
        listContinuations.removeValue(forKey: index)?.resume(
            throwing: BrowseServiceTestError.failed
        )
    }

    func failItem(at index: Int) {
        detailContinuations.removeValue(forKey: index)?.resume(
            throwing: BrowseServiceTestError.failed
        )
    }

    func listWasCancelled(at index: Int) -> Bool {
        listCancellations[index] == true
    }

    func detailWasCancelled(at index: Int) -> Bool {
        detailCancellations[index] == true
    }

    private func notifyCallWaiters() {
        let waiters = callWaiters
        callWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}
