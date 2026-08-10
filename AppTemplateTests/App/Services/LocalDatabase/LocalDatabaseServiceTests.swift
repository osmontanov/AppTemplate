import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseServiceTests {
    @Test
    func invalidInputAndEmptyBatchDoNotInitializeStore() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            containerFactory: recorder.factory
        )

        await expectValidation(.emptyID) {
            _ = try await service.fetchRecord(id: " \n")
        }
        await expectValidation(
            .invalidLimit(actual: 0, allowed: 1...200)
        ) {
            _ = try await service.fetchRecords(
                matching: ExampleQuery(limit: 0)
            )
        }
        try await service.upsert([])
        #expect(recorder.callCount == 0)
    }

    @Test
    func preCancellationPrecedesValidationAndInitialization() async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            containerFactory: recorder.factory
        )

        let result = await resultOfPreCancelledChildTask {
            try await service.fetchRecord(id: "")
        }

        guard case let .failure(error) = result else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.callCount == 0)
    }

    @Test
    func validAndConcurrentCallsInitializeExactlyOnce() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            containerFactory: recorder.factory
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    try await service.upsert(
                        ExampleRecord(
                            id: "record-\(index)",
                            payload: "value-\(index)"
                        )
                    )
                }
            }
            try await group.waitForAll()
        }

        #expect(recorder.callCount == 1)
        #expect(
            try await service.fetchRecords(
                matching: ExampleQuery(limit: 200)
            ).count == 100
        )
    }

    @Test
    func factoryCancellationIsRetriedButOtherFailureIsCached() async throws {
        let cancelled = LocalDatabaseContainerFactoryRecorder { invocation in
            if invocation == 1 { throw CancellationError() }
            return try makeInMemoryLocalDatabaseContainer()
        }
        let retryingService = LocalDatabaseService(
            containerFactory: cancelled.factory
        )
        await expectCancellation {
            _ = try await retryingService.fetchRecord(id: "record-1")
        }
        #expect(
            try await retryingService.fetchRecord(id: "record-1") == nil
        )
        #expect(cancelled.callCount == 2)

        let failed = LocalDatabaseContainerFactoryRecorder { _ in
            throw LocalDatabaseTestError.injectedFailure
        }
        let failedService = LocalDatabaseService(
            containerFactory: failed.factory
        )
        await expectInitializationFailure {
            _ = try await failedService.fetchRecord(id: "record-1")
        }
        await expectInitializationFailure {
            _ = try await failedService.fetchRecord(id: "record-2")
        }
        #expect(failed.callCount == 1)

        await expectValidation(.emptyID) {
            _ = try await failedService.fetchRecord(id: "")
        }
        try await failedService.upsert([])
        let preCancelled = await resultOfPreCancelledChildTask {
            try await failedService.fetchRecord(id: "record-3")
        }
        guard case let .failure(preCancelledError) = preCancelled else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(preCancelledError is CancellationError)
        #expect(failed.callCount == 1)
    }

    @Test
    func cancellationRaisedBySuccessfulFactoryIsObservedBeforeEngineWork() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { invocation in
            if invocation == 1 {
                withUnsafeCurrentTask { $0?.cancel() }
            }
            return try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(containerFactory: recorder.factory)
        let first = Task { () -> Result<ExampleRecord?, any Error> in
            do {
                return .success(
                    try await service.fetchRecord(id: "record-1")
                )
            } catch {
                return .failure(error)
            }
        }

        guard case let .failure(error) = await first.value else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.callCount == 1)
        #expect(try await service.fetchRecord(id: "record-1") == nil)
        #expect(recorder.callCount == 2)
    }
}

private func expectValidation(
    _ expected: LocalDatabaseValidationError,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected LocalDatabaseError.validation")
    } catch let error as LocalDatabaseError {
        guard case let .validation(actual) = error else {
            Issue.record("Expected LocalDatabaseError.validation")
            return
        }
        #expect(actual == expected)
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}

private func expectCancellation(
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected CancellationError")
    } catch {
        #expect(error is CancellationError)
    }
}

private func expectInitializationFailure(
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected LocalDatabaseError.initialization")
    } catch let error as LocalDatabaseError {
        guard case .initialization = error else {
            Issue.record("Expected LocalDatabaseError.initialization")
            return
        }
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}

extension LocalDatabaseServiceTests {
    @Test(arguments: [1, 200])
    func inclusiveQueryLimitsInitializeAndSucceed(limit: Int) async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(containerFactory: recorder.factory)

        #expect(
            try await service.fetchRecords(
                matching: ExampleQuery(limit: limit)
            ).isEmpty
        )
        #expect(recorder.callCount == 1)
    }

    @Test(arguments: [0, 201])
    func outOfRangeQueryLimitsFailBeforeInitialization(limit: Int) async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(containerFactory: recorder.factory)

        await expectValidation(
            .invalidLimit(actual: limit, allowed: 1...200)
        ) {
            _ = try await service.fetchRecords(
                matching: ExampleQuery(limit: limit)
            )
        }
        #expect(recorder.callCount == 0)
    }

    @Test(arguments: ["", " ", "\n\t"])
    func blankIDsFailBeforeInitialization(id: String) async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(containerFactory: recorder.factory)

        await expectValidation(.emptyID) {
            _ = try await service.deleteRecord(id: id)
        }
        #expect(recorder.callCount == 0)
    }

    @Test
    func batchOfFiveHundredSucceedsAndFiveHundredOneFailsBeforeInitialization() async throws {
        let validRecorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let validService = LocalDatabaseService(
            containerFactory: validRecorder.factory
        )
        let fiveHundred = (0..<500).map {
            ExampleRecord(id: "valid-\($0)", payload: "value")
        }
        try await validService.upsert(fiveHundred)
        #expect(validRecorder.callCount == 1)

        let invalidRecorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let invalidService = LocalDatabaseService(
            containerFactory: invalidRecorder.factory
        )
        let fiveHundredOne = (0..<501).map {
            ExampleRecord(id: "invalid-\($0)", payload: "value")
        }
        await expectValidation(
            .batchTooLarge(actual: 501, maximum: 500)
        ) {
            try await invalidService.upsert(fiveHundredOne)
        }
        #expect(invalidRecorder.callCount == 0)
    }

    @Test
    func exactDuplicateBatchIDsFailButCaseDistinctIDsSucceed() async throws {
        let duplicateRecorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let duplicateService = LocalDatabaseService(
            containerFactory: duplicateRecorder.factory
        )
        await expectValidation(.duplicateID) {
            try await duplicateService.upsert([
                ExampleRecord(id: "same", payload: "one"),
                ExampleRecord(id: "same", payload: "two")
            ])
        }
        #expect(duplicateRecorder.callCount == 0)

        let distinctRecorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let distinctService = LocalDatabaseService(
            containerFactory: distinctRecorder.factory
        )
        try await distinctService.upsert([
            ExampleRecord(id: "same", payload: "one"),
            ExampleRecord(id: "SAME", payload: "two")
        ])
        #expect(distinctRecorder.callCount == 1)
    }

    @Test(arguments: LocalDatabasePreCancelledInvocation.allCases)
    func everyPreCancelledPublicOperationSkipsInitialization(
        invocation: LocalDatabasePreCancelledInvocation
    ) async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(containerFactory: recorder.factory)

        let result = await resultOfPreCancelledChildTask {
            try await invocation.invoke(on: service)
        }
        guard case let .failure(error) = result else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.callCount == 0)
    }
}
