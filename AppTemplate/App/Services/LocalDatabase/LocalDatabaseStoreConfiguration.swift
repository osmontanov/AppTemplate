import Foundation
import SwiftData

typealias LocalDatabaseContainerFactory =
    @Sendable () throws -> ModelContainer

nonisolated
enum LocalDatabaseStoreLocationError: Error, Equatable, Sendable {
    case missingBundleIdentifier
}

nonisolated
struct LocalDatabaseStoreLocationResolver: Sendable {
    let resolve: @Sendable () throws -> URL

    static func live(
        applicationSupportDirectory:
            @escaping @Sendable () throws -> URL = {
                try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )
            },
        bundleIdentifier:
            @escaping @Sendable () -> String? = {
                Bundle.main.bundleIdentifier
            },
        createDirectory:
            @escaping @Sendable (URL) throws -> Void = { url in
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true
                )
            }
    ) -> LocalDatabaseStoreLocationResolver {
        LocalDatabaseStoreLocationResolver {
            guard
                let identifier = bundleIdentifier(),
                !identifier.isEmpty
            else {
                throw LocalDatabaseStoreLocationError
                    .missingBundleIdentifier
            }

            let directory = try applicationSupportDirectory()
                .appending(
                    path: identifier,
                    directoryHint: .isDirectory
                )
            try createDirectory(directory)
            return directory.appending(
                path: "LocalDatabase.store",
                directoryHint: .notDirectory
            )
        }
    }
}

nonisolated
enum LocalDatabaseContainerFactories {
    static func live(
        locationResolver: LocalDatabaseStoreLocationResolver = .live()
    ) -> LocalDatabaseContainerFactory {
        {
            try disk(url: locationResolver.resolve())()
        }
    }

    static func disk(url: URL) -> LocalDatabaseContainerFactory {
        {
            let schema = Schema(
                versionedSchema: LocalDatabaseSchemaV1.self
            )
            let configuration = ModelConfiguration(
                "LocalDatabase",
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: LocalDatabaseMigrationPlan.self,
                configurations: [configuration]
            )
        }
    }

    static func inMemory() -> LocalDatabaseContainerFactory {
        {
            let schema = Schema(
                versionedSchema: LocalDatabaseSchemaV1.self
            )
            let configuration = ModelConfiguration(
                "LocalDatabase",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: LocalDatabaseMigrationPlan.self,
                configurations: [configuration]
            )
        }
    }
}

nonisolated
struct LocalDatabaseStoreConfiguration: Sendable {
    let containerFactory: LocalDatabaseContainerFactory
    let modelRegistry: LocalDatabaseModelRegistry

    static func live(
        locationResolver: LocalDatabaseStoreLocationResolver = .live()
    ) -> LocalDatabaseStoreConfiguration {
        LocalDatabaseStoreConfiguration(
            containerFactory: LocalDatabaseContainerFactories.live(
                locationResolver: locationResolver
            ),
            modelRegistry: .production
        )
    }

    static func disk(url: URL) -> LocalDatabaseStoreConfiguration {
        LocalDatabaseStoreConfiguration(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url),
            modelRegistry: .production
        )
    }

    static func inMemory() -> LocalDatabaseStoreConfiguration {
        LocalDatabaseStoreConfiguration(
            containerFactory: LocalDatabaseContainerFactories.inMemory(),
            modelRegistry: .production
        )
    }
}
