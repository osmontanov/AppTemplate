import Foundation
import Nuke

nonisolated
enum ImageDiskCache {
    enum DiskCacheError: Error, Equatable, Sendable {
        case invalidDirectory
    }

    static func defaultDirectory(
        caches: URL? = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first
    ) -> URL? {
        caches?
            .appending(path: AppNamespace.primary, directoryHint: .isDirectory)
            .appending(path: "Images", directoryHint: .isDirectory)
            .standardizedFileURL
    }

    // Nuke's DataCache writes with a bare `data.write(to:)` and cannot set a
    // protection class itself, so the directory has to carry it and let the
    // files it creates inherit.
    static func make(directory: URL, sizeLimit: Int) throws -> DataCache {
        guard directory.isFileURL else { throw DiskCacheError.invalidDirectory }
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            let values = try directory.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard isDirectory.boolValue,
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else {
                throw DiskCacheError.invalidDirectory
            }
        } else {
            var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
            #if !os(macOS)
            // Not `.complete`: DataCache writes asynchronously and swallows write
            // errors, so a locked device would silently stop caching and silently
            // resume. This class keeps the cache working and still encrypts at rest.
            attributes[.protectionKey] = FileProtectionType.completeUntilFirstUserAuthentication
            #endif
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: attributes
            )
        }
        let cache = try DataCache(path: directory)
        cache.sizeLimit = sizeLimit
        return cache
    }

    // Fail-open on the cache, fail-closed on the data: a cache that cannot be
    // created degrades to memory-only rather than taking the app down.
    static func live(
        directory: URL? = defaultDirectory(),
        sizeLimit: Int = 64 * 1_024 * 1_024
    ) -> (any DataCaching)? {
        guard let directory else { return nil }
        return try? make(directory: directory, sizeLimit: sizeLimit)
    }
}
