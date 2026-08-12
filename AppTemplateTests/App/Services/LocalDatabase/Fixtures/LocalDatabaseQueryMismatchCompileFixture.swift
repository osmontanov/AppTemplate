#if LOCAL_DATABASE_QUERY_MISMATCH_COMPILE_FIXTURE
@testable import AppTemplate

func compileQueryMismatch(
    database: any ILocalDatabaseService,
    query: TestLocalQuery
) async throws {
    _ = try await database.fetch(
        ExampleRecord.self,
        matching: query
    )
}
#endif
