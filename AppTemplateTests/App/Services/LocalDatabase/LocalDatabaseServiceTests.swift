import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseServiceTests {
    @Test
    func invalidExampleInputAndEmptyRegisteredBatchDoNotInitializeStore()
        async throws
    {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        await expectValidation(.emptyID) {
            _ = try await service.fetch(ExampleRecord.self, id: " \n")
        }
        await expectValidation(
            .invalidLimit(actual: 0, allowed: 1...200)
        ) {
            _ = try await service.fetch(
                ExampleRecord.self,
                matching: ExampleQuery(limit: 0)
            )
        }
        try await service.upsert([ExampleRecord]())
        #expect(recorder.callCount == 0)
    }

    @Test
    func unregisteredModelFailsBeforeStoreInitialization() async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        await expectValidation(
            .unregisteredModel,
            model: TestLocalRecordAdapter.diagnosticName
        ) {
            _ = try await service.fetch(
                TestLocalRecord.self,
                id: TestLocalRecordID(rawValue: 1)
            )
        }
        #expect(recorder.callCount == 0)
    }

    @Test
    func emptyUnregisteredBatchFailsBeforeNoOpAndInitialization() async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        await expectValidation(
            .unregisteredModel,
            model: TestLocalRecordAdapter.diagnosticName
        ) {
            try await service.upsert([TestLocalRecord]())
        }
        #expect(recorder.callCount == 0)
    }

    @Test
    func invalidRegistryFailsBeforeContainerFactory() async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let invalidRegistry = LocalDatabaseModelRegistry(adapters: [
            ExampleRecordAdapter.self,
            ExampleRecordAdapter.self
        ])
        let service = LocalDatabaseService(
            configuration: recorder.configuration(registry: invalidRegistry)
        )

        await expectInitializationFailure {
            try await service.upsert([ExampleRecord]())
        }
        #expect(recorder.callCount == 0)
    }

    @Test
    func preCancellationPrecedesValidationRegistrationAndInitialization()
        async
    {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let invalidRegistry = LocalDatabaseModelRegistry(adapters: [
            ExampleRecordAdapter.self,
            ExampleRecordAdapter.self
        ])
        let service = LocalDatabaseService(
            configuration: recorder.configuration(registry: invalidRegistry)
        )

        let result = await resultOfPreCancelledChildTask {
            try await service.fetch(ExampleRecord.self, id: "")
        }

        guard case let .failure(error) = result else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.callCount == 0)
    }

    @Test
    func validConcurrentGenericCallsInitializeExactlyOnce() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
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
            try await service.fetch(
                ExampleRecord.self,
                matching: ExampleQuery(limit: 200)
            ).count == 100
        )
    }

    @Test
    func bootstrapCancellationRetries() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { invocation in
            if invocation == 1 { throw CancellationError() }
            return try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        await expectCancellation {
            _ = try await service.fetch(ExampleRecord.self, id: "record-1")
        }
        #expect(
            try await service.fetch(ExampleRecord.self, id: "record-1") == nil
        )
        #expect(recorder.callCount == 2)
    }

    @Test
    func nonCancellationBootstrapFailureIsCached() async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            throw LocalDatabaseTestError.injectedFailure
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        await expectInitializationFailure {
            _ = try await service.fetch(ExampleRecord.self, id: "record-1")
        }
        await expectInitializationFailure {
            _ = try await service.fetch(ExampleRecord.self, id: "record-2")
        }
        #expect(recorder.callCount == 1)
    }

    @Test
    func validationRegistrationNoOpAndCancellationPrecedeCachedFailure()
        async throws
    {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            throw LocalDatabaseTestError.injectedFailure
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )
        await expectInitializationFailure {
            _ = try await service.fetch(ExampleRecord.self, id: "record-1")
        }

        await expectValidation(.emptyID) {
            _ = try await service.fetch(ExampleRecord.self, id: "")
        }
        await expectValidation(
            .unregisteredModel,
            model: TestLocalRecordAdapter.diagnosticName
        ) {
            _ = try await service.deleteAll(TestLocalRecord.self)
        }
        try await service.upsert([ExampleRecord]())
        let preCancelled = await resultOfPreCancelledChildTask {
            try await service.fetch(ExampleRecord.self, id: "record-3")
        }
        guard case let .failure(preCancelledError) = preCancelled else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(preCancelledError is CancellationError)
        #expect(recorder.callCount == 1)
    }

    @Test
    func successfulFactoryCancellationIsObservedBeforeEngineWork()
        async throws
    {
        let recorder = LocalDatabaseContainerFactoryRecorder { invocation in
            if invocation == 1 {
                withUnsafeCurrentTask { $0?.cancel() }
            }
            return try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )
        let first: Result<ExampleRecord?, any Error> = await resultOfChildTask {
            try await service.fetch(ExampleRecord.self, id: "record-1")
        }

        guard case let .failure(error) = first else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.callCount == 1)
        #expect(
            try await service.fetch(ExampleRecord.self, id: "record-1") == nil
        )
        #expect(recorder.callCount == 2)
    }
}

private func expectValidation(
    _ expected: LocalDatabaseValidationError,
    model: String = ExampleRecordAdapter.diagnosticName,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected LocalDatabaseError.validation")
    } catch let error as LocalDatabaseError {
        guard case let .validation(actualModel, actualReason) = error else {
            Issue.record("Expected LocalDatabaseError.validation")
            return
        }
        #expect(actualModel == model)
        #expect(actualReason == expected)
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
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        #expect(
            try await service.fetch(
                ExampleRecord.self,
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
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        await expectValidation(
            .invalidLimit(actual: limit, allowed: 1...200)
        ) {
            _ = try await service.fetch(
                ExampleRecord.self,
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
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

        await expectValidation(.emptyID) {
            _ = try await service.delete(ExampleRecord.self, id: id)
        }
        #expect(recorder.callCount == 0)
    }

    @Test
    func batchOfFiveHundredSucceedsAndFiveHundredOneFailsBeforeInitialization()
        async throws
    {
        let validRecorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let validService = LocalDatabaseService(
            configuration: validRecorder.configuration()
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
            configuration: invalidRecorder.configuration()
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
            configuration: duplicateRecorder.configuration()
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
            configuration: distinctRecorder.configuration()
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
        let service = LocalDatabaseService(
            configuration: recorder.configuration()
        )

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
