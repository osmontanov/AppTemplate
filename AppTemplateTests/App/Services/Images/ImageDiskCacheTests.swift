import Foundation
import Nuke
import Testing
@testable import AppTemplate

struct ImageDiskCacheTests {
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AppTemplate-ImageDiskCacheTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    @Test
    func createsALockedDownDirectoryAndAppliesTheSizeLimit() throws {
        let directory = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = try ImageDiskCache.make(directory: directory, sizeLimit: 1_234)

        #expect(cache.sizeLimit == 1_234)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #if !os(macOS)
        #expect(
            attributes[.protectionKey] as? FileProtectionType
                == .completeUntilFirstUserAuthentication
        )
        #endif
    }

    @Test
    func refusesAPathThatIsAlreadyAFile() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("occupied")
        try Data("not a directory".utf8).write(to: file)

        #expect(throws: ImageDiskCache.DiskCacheError.invalidDirectory) {
            _ = try ImageDiskCache.make(directory: file, sizeLimit: 16)
        }
    }

    @Test
    func refusesASymlinkedDirectory() throws {
        let root = temporaryRoot()
        let real = root.appendingPathComponent("real", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        #expect(throws: ImageDiskCache.DiskCacheError.invalidDirectory) {
            _ = try ImageDiskCache.make(directory: link, sizeLimit: 16)
        }
    }

    @Test
    func defaultDirectorySitsUnderTheAppNamespaceAndDegradesWithoutACachesURL() throws {
        let caches = URL(fileURLWithPath: "/tmp/caches", isDirectory: true)
        let directory = try #require(ImageDiskCache.defaultDirectory(caches: caches))

        #expect(directory.lastPathComponent == "Images")
        #expect(directory.deletingLastPathComponent().lastPathComponent == AppNamespace.primary)
        #expect(ImageDiskCache.defaultDirectory(caches: nil) == nil)
    }

    @Test
    func liveFailsOpenToMemoryOnlyWhenTheDirectoryCannotBeCreated() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("occupied")
        try Data("not a directory".utf8).write(to: file)

        #expect(ImageDiskCache.live(directory: file) == nil)
        #expect(ImageDiskCache.live(directory: nil) == nil)
    }
}
