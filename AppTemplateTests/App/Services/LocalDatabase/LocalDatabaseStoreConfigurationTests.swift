import Foundation
import SwiftData
import Synchronization
import Testing
@testable import AppTemplate

struct LocalDatabaseStoreConfigurationTests {
    @Test
    func liveResolverBuildsStableBundleScopedURLLazily() throws {
        let recorder = DirectoryCreationRecorder()
        let root = URL(filePath: "/tmp/AppTemplate-Resolver-Fixture", directoryHint: .isDirectory)
        let resolver = LocalDatabaseStoreLocationResolver.live(
            applicationSupportDirectory: { root },
            bundleIdentifier: { "com.example.AppTemplate" },
            createDirectory: { recorder.record($0) }
        )

        #expect(recorder.urls.isEmpty)

        let url = try resolver.resolve()

        let expectedDirectory = root.appending(
            path: "com.example.AppTemplate",
            directoryHint: .isDirectory
        )
        #expect(recorder.urls == [expectedDirectory])
        #expect(
            url
                == expectedDirectory.appending(
                    path: "LocalDatabase.store",
                    directoryHint: .notDirectory
                )
        )
    }

    @Test
    func liveResolverRejectsMissingOrEmptyBundleIdentifier() {
        for identifier: String? in [nil, ""] {
            let resolver = LocalDatabaseStoreLocationResolver.live(
                applicationSupportDirectory: {
                    URL(filePath: "/tmp", directoryHint: .isDirectory)
                },
                bundleIdentifier: { identifier },
                createDirectory: { _ in }
            )

            #expect(throws: LocalDatabaseStoreLocationError.self) {
                _ = try resolver.resolve()
            }
        }
    }

    @Test
    func liveResolverPropagatesDirectoryCreationFailure() {
        let resolver = LocalDatabaseStoreLocationResolver.live(
            applicationSupportDirectory: {
                URL(filePath: "/tmp", directoryHint: .isDirectory)
            },
            bundleIdentifier: { "com.example.AppTemplate" },
            createDirectory: { _ in
                throw ConfigurationFixtureError.directoryCreation
            }
        )

        #expect(throws: ConfigurationFixtureError.self) {
            _ = try resolver.resolve()
        }
    }

    @Test
    func liveFactoryDoesNotResolveLocationUntilInvoked() throws {
        let calls = SynchronousCounter()
        let url = try uniqueLocalDatabaseStoreURL(label: "lazy-live")
        let factory = LocalDatabaseContainerFactories.live(
            locationResolver: .init(resolve: {
                calls.increment()
                return url
            })
        )

        #expect(calls.value == 0)
        _ = try factory()
        #expect(calls.value == 1)
    }

    @Test
    func inMemoryFactoryCreatesIndependentContainers() throws {
        let factory = LocalDatabaseContainerFactories.inMemory()
        let first = try factory()
        let second = try factory()

        #expect(first !== second)
        let firstIsInMemory = first.configurations.allSatisfy(
            \.isStoredInMemoryOnly
        )
        let secondIsInMemory = second.configurations.allSatisfy(
            \.isStoredInMemoryOnly
        )
        #expect(firstIsInMemory)
        #expect(secondIsInMemory)
    }

    @Test
    func diskFactoryUsesExactURLAndAllowsSave() throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "configuration")
        let container = try LocalDatabaseContainerFactories.disk(url: url)()
        let configuration = try #require(container.configurations.first)

        #expect(configuration.url == url)
        #expect(configuration.allowsSave)
        #expect(!configuration.isStoredInMemoryOnly)
    }

    @Test
    func schemaEnforcesOneStoredEntityPerBusinessID() throws {
        let container = try LocalDatabaseContainerFactories.inMemory()()
        let firstContext = ModelContext(container)
        firstContext.autosaveEnabled = false
        firstContext.insert(
            LocalDatabaseSchemaV1.StoredExampleRecord(
                id: "same",
                payload: "first"
            )
        )
        try firstContext.save()

        let secondContext = ModelContext(container)
        secondContext.autosaveEnabled = false
        secondContext.insert(
            LocalDatabaseSchemaV1.StoredExampleRecord(
                id: "same",
                payload: "second"
            )
        )
        try secondContext.save()

        let verifier = ModelContext(container)
        let rows = try verifier.fetch(
            FetchDescriptor<
                LocalDatabaseSchemaV1.StoredExampleRecord
            >()
        )
        #expect(rows.count == 1)
        #expect(rows.first?.payload == "second")
    }
}

nonisolated
private final class DirectoryCreationRecorder: Sendable {
    private let storage = Mutex<[URL]>([])

    var urls: [URL] { storage.withLock { $0 } }

    func record(_ url: URL) {
        storage.withLock { $0.append(url) }
    }
}

nonisolated
private enum ConfigurationFixtureError: Error, Sendable {
    case directoryCreation
}

nonisolated
private final class SynchronousCounter: Sendable {
    private let storage = Mutex(0)

    var value: Int { storage.withLock { $0 } }

    func increment() {
        storage.withLock { $0 += 1 }
    }
}

private func uniqueLocalDatabaseStoreURL(label: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "AppTemplate-SwiftData-\(label)-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return directory.appending(
        path: "LocalDatabase.store",
        directoryHint: .notDirectory
    )
}
