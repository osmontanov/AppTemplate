import Foundation
import OSLog

nonisolated
enum LocalDatabaseDiagnosticOperation: Equatable, Sendable {
    case initialization
    case read(LocalDatabaseReadOperation)
    case write(LocalDatabaseWriteOperation)
}

nonisolated
struct LocalDatabaseFailureMetadata: Equatable, Sendable {
    let operation: LocalDatabaseDiagnosticOperation
    let entityType: String
    let recordCount: Int
    let errorDomain: String
    let errorCode: Int
}

nonisolated
enum LocalDatabaseDiagnostics {
    private static let logger = Logger(
        subsystem: "AppTemplate",
        category: "LocalDatabase"
    )

    static func metadata(
        operation: LocalDatabaseDiagnosticOperation,
        entityType: String,
        recordCount: Int,
        error: any Error
    ) -> LocalDatabaseFailureMetadata {
        let frameworkError = error as NSError
        return LocalDatabaseFailureMetadata(
            operation: operation,
            entityType: entityType,
            recordCount: recordCount,
            errorDomain: frameworkError.domain,
            errorCode: frameworkError.code
        )
    }

    static func report(
        operation: LocalDatabaseDiagnosticOperation,
        entityType: String,
        recordCount: Int,
        error: any Error
    ) {
        let value = metadata(
            operation: operation,
            entityType: entityType,
            recordCount: recordCount,
            error: error
        )
        logger.error("operation=\(String(describing: value.operation), privacy: .public) entity=\(value.entityType, privacy: .public) count=\(value.recordCount, privacy: .public) domain=\(value.errorDomain, privacy: .public) code=\(value.errorCode, privacy: .public)")
    }
}
