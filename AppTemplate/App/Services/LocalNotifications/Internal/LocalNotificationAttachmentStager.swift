import Foundation
import Synchronization
import UniformTypeIdentifiers

#if canImport(Darwin)
import Darwin
#endif

nonisolated
enum LocalNotificationMediaKind: Hashable, Sendable {
    case image(typeIdentifier: String, filenameExtension: String)
    case audio(typeIdentifier: String, filenameExtension: String)
    case movie(typeIdentifier: String, filenameExtension: String)

    var typeIdentifier: String {
        switch self {
        case let .image(typeIdentifier, _),
             let .audio(typeIdentifier, _),
             let .movie(typeIdentifier, _):
            typeIdentifier
        }
    }

    var filenameExtension: String {
        switch self {
        case let .image(_, filenameExtension),
             let .audio(_, filenameExtension),
             let .movie(_, filenameExtension):
            filenameExtension
        }
    }
}

nonisolated
protocol LocalNotificationMediaTypeResolving: Sendable {
    func mediaKind(for url: URL, fileTypeHint: String?) -> LocalNotificationMediaKind?
}

nonisolated
struct UniformTypeIdentifiersLocalNotificationMediaResolver: LocalNotificationMediaTypeResolving {
    func mediaKind(for url: URL, fileTypeHint: String?) -> LocalNotificationMediaKind? {
        let inferredType = url.pathExtension.isEmpty
            ? nil
            : UTType(filenameExtension: url.pathExtension)
        let resolvedType: UTType

        if let fileTypeHint {
            guard let hintedType = UTType(fileTypeHint), Self.isSupported(hintedType) else {
                return nil
            }
            resolvedType = hintedType
        } else {
            guard let inferredType, Self.isSupported(inferredType) else {
                return nil
            }
            resolvedType = inferredType
        }

        let extensionType: UTType
        if resolvedType.preferredFilenameExtension != nil {
            extensionType = resolvedType
        } else if let inferredType, inferredType.conforms(to: resolvedType) {
            extensionType = inferredType
        } else {
            return nil
        }
        guard let filenameExtension = extensionType.preferredFilenameExtension,
              LocalNotificationAttachmentStager.isSafe(filenameExtension: filenameExtension) else {
            return nil
        }

        if resolvedType.conforms(to: .image) {
            return .image(
                typeIdentifier: resolvedType.identifier,
                filenameExtension: filenameExtension.lowercased()
            )
        }
        if resolvedType.conforms(to: .audio) {
            return .audio(
                typeIdentifier: resolvedType.identifier,
                filenameExtension: filenameExtension.lowercased()
            )
        }
        if resolvedType.conforms(to: .movie) {
            return .movie(
                typeIdentifier: resolvedType.identifier,
                filenameExtension: filenameExtension.lowercased()
            )
        }
        return nil
    }

    private static func isSupported(_ type: UTType) -> Bool {
        type.conforms(to: .image) || type.conforms(to: .audio) || type.conforms(to: .movie)
    }
}

nonisolated
protocol LocalNotificationSecurityScopeAccessing: Sendable {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

nonisolated
struct URLLocalNotificationSecurityScopeAccessor: LocalNotificationSecurityScopeAccessing {
    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

nonisolated
struct LocalNotificationStagingFileDescriptor: Hashable, Sendable {
    let rawValue: Int32
}

nonisolated
struct LocalNotificationFileIdentity: Hashable, Sendable {
    let device: UInt64
    let inode: UInt64
}

nonisolated
enum LocalNotificationStagingFileSystemError: Error, Equatable, Sendable {
    case missing
    case symbolicLink
    case notDirectory
    case notRegularFile
    case unreadable
    case alreadyExists
    case system(Int32)
}

nonisolated
protocol LocalNotificationStagingFileSystem: Sendable {
    func openDirectory(at url: URL) throws -> LocalNotificationStagingFileDescriptor
    func createDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws
    func openDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationStagingFileDescriptor
    func openSourceFile(at url: URL) throws -> LocalNotificationStagingFileDescriptor
    func createFile(
        named name: String,
        in directory: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationStagingFileDescriptor
    func identity(
        of descriptor: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationFileIdentity
    func identity(
        ofEntryNamed name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationFileIdentity?
    func read(
        from descriptor: LocalNotificationStagingFileDescriptor,
        maximumCount: Int
    ) throws -> Data
    func write(
        _ data: Data,
        fromOffset offset: Int,
        to descriptor: LocalNotificationStagingFileDescriptor
    ) throws -> Int
    func unlinkFile(
        named name: String,
        in directory: LocalNotificationStagingFileDescriptor
    ) throws
    func unlinkDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws
    func close(_ descriptor: LocalNotificationStagingFileDescriptor)
}

nonisolated
struct POSIXLocalNotificationStagingFileSystem: LocalNotificationStagingFileSystem {
    func openDirectory(at url: URL) throws -> LocalNotificationStagingFileDescriptor {
        try openAbsolutePath(url, finalFlags: O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    }

    func createDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws {
        guard Self.isSingleComponent(name) else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        guard mkdirat(parent.rawValue, name, mode_t(0o700)) == 0 else {
            throw Self.error(for: errno)
        }
    }

    func openDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationStagingFileDescriptor {
        guard Self.isSingleComponent(name) else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        let rawDescriptor = openat(
            parent.rawValue,
            name,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard rawDescriptor >= 0 else {
            throw Self.entryError(for: errno, name: name, parent: parent)
        }
        return LocalNotificationStagingFileDescriptor(rawValue: rawDescriptor)
    }

    func openSourceFile(at url: URL) throws -> LocalNotificationStagingFileDescriptor {
        let descriptor = try openAbsolutePath(
            url,
            finalFlags: O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        do {
            var metadata = stat()
            guard fstat(descriptor.rawValue, &metadata) == 0 else {
                throw Self.error(for: errno)
            }
            guard (metadata.st_mode & S_IFMT) == S_IFREG else {
                throw LocalNotificationStagingFileSystemError.notRegularFile
            }
            guard (metadata.st_mode & mode_t(0o444)) != 0 else {
                throw LocalNotificationStagingFileSystemError.unreadable
            }
            return descriptor
        } catch {
            close(descriptor)
            throw error
        }
    }

    func createFile(
        named name: String,
        in directory: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationStagingFileDescriptor {
        guard Self.isSingleComponent(name) else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        let rawDescriptor = openat(
            directory.rawValue,
            name,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            mode_t(0o600)
        )
        guard rawDescriptor >= 0 else {
            throw Self.error(for: errno)
        }
        return LocalNotificationStagingFileDescriptor(rawValue: rawDescriptor)
    }

    func identity(
        of descriptor: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationFileIdentity {
        var metadata = stat()
        guard fstat(descriptor.rawValue, &metadata) == 0 else {
            throw Self.error(for: errno)
        }
        return Self.identity(metadata)
    }

    func identity(
        ofEntryNamed name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationFileIdentity? {
        guard Self.isSingleComponent(name) else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        var metadata = stat()
        guard fstatat(parent.rawValue, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0 else {
            let capturedError = errno
            if capturedError == ENOENT {
                return nil
            }
            throw Self.error(for: capturedError)
        }
        return Self.identity(metadata)
    }

    func read(
        from descriptor: LocalNotificationStagingFileDescriptor,
        maximumCount: Int
    ) throws -> Data {
        guard maximumCount > 0 else { return Data() }
        var buffer = [UInt8](repeating: 0, count: maximumCount)
        while true {
            let count = Darwin.read(descriptor.rawValue, &buffer, maximumCount)
            if count >= 0 {
                return Data(buffer.prefix(Int(count)))
            }
            guard errno == EINTR else {
                throw Self.error(for: errno)
            }
        }
    }

    func write(
        _ data: Data,
        fromOffset offset: Int,
        to descriptor: LocalNotificationStagingFileDescriptor
    ) throws -> Int {
        guard offset >= 0, offset <= data.count else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        guard offset < data.count else { return 0 }
        return try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            while true {
                let count = Darwin.write(
                    descriptor.rawValue,
                    baseAddress.advanced(by: offset),
                    data.count - offset
                )
                if count >= 0 {
                    return count
                }
                guard errno == EINTR else {
                    throw Self.error(for: errno)
                }
            }
        }
    }

    func unlinkFile(
        named name: String,
        in directory: LocalNotificationStagingFileDescriptor
    ) throws {
        guard Self.isSingleComponent(name) else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        guard unlinkat(directory.rawValue, name, 0) == 0 else {
            throw Self.error(for: errno)
        }
    }

    func unlinkDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws {
        guard Self.isSingleComponent(name) else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        guard unlinkat(parent.rawValue, name, AT_REMOVEDIR) == 0 else {
            throw Self.error(for: errno)
        }
    }

    func close(_ descriptor: LocalNotificationStagingFileDescriptor) {
        _ = Darwin.close(descriptor.rawValue)
    }

    private func openAbsolutePath(
        _ url: URL,
        finalFlags: Int32
    ) throws -> LocalNotificationStagingFileDescriptor {
        let components = try Self.pathComponents(of: url)
        var current = LocalNotificationStagingFileDescriptor(
            rawValue: Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        )
        guard current.rawValue >= 0 else {
            throw Self.error(for: errno)
        }

        do {
            for (index, component) in components.enumerated() {
                let isFinal = index == components.index(before: components.endIndex)
                let flags = isFinal
                    ? finalFlags
                    : O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
                let nextRaw = openat(current.rawValue, component, flags)
                guard nextRaw >= 0 else {
                    throw Self.entryError(for: errno, name: component, parent: current)
                }
                let next = LocalNotificationStagingFileDescriptor(rawValue: nextRaw)
                close(current)
                current = next
            }
            return current
        } catch {
            close(current)
            throw error
        }
    }

    private static func pathComponents(of url: URL) throws -> [String] {
        guard url.isFileURL,
              url.path.hasPrefix("/"),
              url.host == nil || url.host?.isEmpty == true || url.host == "localhost" else {
            throw LocalNotificationStagingFileSystemError.system(EINVAL)
        }
        let components = Array(url.pathComponents.dropFirst())
        guard !components.isEmpty, components.allSatisfy(isSingleComponent) else {
            throw LocalNotificationStagingFileSystemError.symbolicLink
        }
        return components
    }

    private static func isSingleComponent(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }

    private static func entryError(
        for errorNumber: Int32,
        name: String,
        parent: LocalNotificationStagingFileDescriptor
    ) -> LocalNotificationStagingFileSystemError {
        if errorNumber == ELOOP || errorNumber == ENOTDIR {
            var metadata = stat()
            if fstatat(parent.rawValue, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0,
               (metadata.st_mode & S_IFMT) == S_IFLNK {
                return .symbolicLink
            }
        }
        return error(for: errorNumber)
    }

    private static func error(for errorNumber: Int32) -> LocalNotificationStagingFileSystemError {
        switch errorNumber {
        case ENOENT:
            .missing
        case ELOOP:
            .symbolicLink
        case ENOTDIR:
            .notDirectory
        case EACCES, EPERM:
            .unreadable
        case EEXIST:
            .alreadyExists
        default:
            .system(errorNumber)
        }
    }

    private static func identity(_ metadata: stat) -> LocalNotificationFileIdentity {
        LocalNotificationFileIdentity(
            device: UInt64(truncatingIfNeeded: metadata.st_dev),
            inode: UInt64(truncatingIfNeeded: metadata.st_ino)
        )
    }
}

nonisolated
enum LocalNotificationStagingCleanupOutcome: Hashable, Sendable {
    case removed
    case alreadyCleaned
    case replacementDetected
    case failed
}

private nonisolated final class LocalNotificationStagingOwnership: Hashable, Sendable {
    private struct ActiveState: Sendable {
        let rootDescriptor: LocalNotificationStagingFileDescriptor
        let rootIdentity: LocalNotificationFileIdentity
        let operationDescriptor: LocalNotificationStagingFileDescriptor
        let operationIdentity: LocalNotificationFileIdentity
        let operationName: String
        var generatedFiles: Set<String>
    }

    private enum State: Sendable {
        case active(ActiveState)
        case cleaning
        case closed(LocalNotificationStagingCleanupOutcome)
    }

    private let fileSystem: any LocalNotificationStagingFileSystem
    private let state: Mutex<State>

    init(
        fileSystem: any LocalNotificationStagingFileSystem,
        rootDescriptor: LocalNotificationStagingFileDescriptor,
        rootIdentity: LocalNotificationFileIdentity,
        operationDescriptor: LocalNotificationStagingFileDescriptor,
        operationIdentity: LocalNotificationFileIdentity,
        operationName: String
    ) {
        self.fileSystem = fileSystem
        state = Mutex(
            .active(
                ActiveState(
                    rootDescriptor: rootDescriptor,
                    rootIdentity: rootIdentity,
                    operationDescriptor: operationDescriptor,
                    operationIdentity: operationIdentity,
                    operationName: operationName,
                    generatedFiles: []
                )
            )
        )
    }

    static func == (lhs: LocalNotificationStagingOwnership, rhs: LocalNotificationStagingOwnership) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    func registerGeneratedFile(_ name: String) {
        state.withLock { state in
            guard case var .active(active) = state else {
                preconditionFailure("Staging ownership is not active")
            }
            guard active.generatedFiles.insert(name).inserted else {
                preconditionFailure("Generated staging filename was reused")
            }
            state = .active(active)
        }
    }

    func withOperationDescriptor<T: ~Copyable>(
        _ body: (borrowing LocalNotificationStagingFileDescriptor) throws -> T
    ) rethrows -> T {
        try state.withLock { state in
            guard case let .active(active) = state else {
                preconditionFailure("Staging ownership is not active")
            }
            return try body(active.operationDescriptor)
        }
    }

    func cleanup() -> LocalNotificationStagingCleanupOutcome {
        let active: ActiveState? = state.withLock { state in
            guard case let .active(active) = state else { return nil }
            state = .cleaning
            return active
        }
        guard let active else { return .alreadyCleaned }

        let outcome = removeOwnedContents(active)
        fileSystem.close(active.operationDescriptor)
        fileSystem.close(active.rootDescriptor)
        state.withLock { $0 = .closed(outcome) }
        return outcome
    }

    deinit {
        _ = cleanup()
    }

    private func removeOwnedContents(_ active: ActiveState) -> LocalNotificationStagingCleanupOutcome {
        var removalFailed = false
        for name in active.generatedFiles {
            do {
                try fileSystem.unlinkFile(named: name, in: active.operationDescriptor)
            } catch LocalNotificationStagingFileSystemError.missing {
                continue
            } catch {
                removalFailed = true
            }
        }
        guard !removalFailed else { return .failed }

        do {
            guard try fileSystem.identity(of: active.rootDescriptor) == active.rootIdentity,
                  try fileSystem.identity(of: active.operationDescriptor) == active.operationIdentity,
                  try fileSystem.identity(
                    ofEntryNamed: active.operationName,
                    in: active.rootDescriptor
                  ) == active.operationIdentity else {
                return .replacementDetected
            }
            // Darwin has no public identity-conditioned rmdir. This checked unlink is safe
            // within the app-owned staging namespace, not against an active same-UID swap.
            try fileSystem.unlinkDirectory(
                named: active.operationName,
                in: active.rootDescriptor
            )
            return .removed
        } catch LocalNotificationStagingFileSystemError.missing {
            return .replacementDetected
        } catch {
            return .failed
        }
    }
}

nonisolated
struct LocalNotificationStagedAttachment: Hashable, Sendable {
    let systemAttachment: LocalNotificationSystemAttachment
    let typeIdentifier: String
    fileprivate let cleanupOwner: LocalNotificationStagingOwnership

    var url: URL { systemAttachment.fileURL }
}

nonisolated
struct LocalNotificationAttachmentStager {
    typealias TemporaryRootFactory = @Sendable (FileManager) throws -> URL
    typealias CheckCancellation = @Sendable () throws -> Void

    private static let directoryPrefix = "LocalNotificationAttachments-"
    private static let copyBufferSize = 64 * 1_024

    private let fileManager: FileManager
    private let temporaryRootFactory: TemporaryRootFactory
    private let mediaTypeResolver: any LocalNotificationMediaTypeResolving
    private let securityScopeAccessor: any LocalNotificationSecurityScopeAccessing
    private let fileSystem: any LocalNotificationStagingFileSystem
    private let checkCancellation: CheckCancellation

    init(
        fileManager: FileManager,
        temporaryRootFactory: @escaping TemporaryRootFactory,
        mediaTypeResolver: any LocalNotificationMediaTypeResolving,
        securityScopeAccessor: any LocalNotificationSecurityScopeAccessing,
        fileSystem: any LocalNotificationStagingFileSystem = POSIXLocalNotificationStagingFileSystem(),
        checkCancellation: @escaping CheckCancellation = { try Task.checkCancellation() }
    ) {
        self.fileManager = fileManager
        self.temporaryRootFactory = temporaryRootFactory
        self.mediaTypeResolver = mediaTypeResolver
        self.securityScopeAccessor = securityScopeAccessor
        self.fileSystem = fileSystem
        self.checkCancellation = checkCancellation
    }

    static func live(fileManager: FileManager = .default) -> Self {
        Self(
            fileManager: fileManager,
            temporaryRootFactory: {
                $0.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL
            },
            mediaTypeResolver: UniformTypeIdentifiersLocalNotificationMediaResolver(),
            securityScopeAccessor: URLLocalNotificationSecurityScopeAccessor()
        )
    }

    static func temporary(
        root: URL,
        mediaTypeResolver: any LocalNotificationMediaTypeResolving = UniformTypeIdentifiersLocalNotificationMediaResolver(),
        securityScopeAccessor: any LocalNotificationSecurityScopeAccessing = URLLocalNotificationSecurityScopeAccessor()
    ) -> Self {
        Self(
            fileManager: .default,
            temporaryRootFactory: { _ in root },
            mediaTypeResolver: mediaTypeResolver,
            securityScopeAccessor: securityScopeAccessor
        )
    }

    func stage(
        _ attachments: [LocalNotificationAttachment],
        requestID: LocalNotificationID
    ) throws -> [LocalNotificationStagedAttachment] {
        try checkCancellation()
        try validateLogicalAttachments(attachments)
        guard let firstAttachment = attachments.first else { return [] }

        let root: URL
        do {
            root = try validatedRoot(temporaryRootFactory(fileManager))
            try checkCancellation()
        } catch let error as CancellationError {
            throw error
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(firstAttachment.id, .stagingFailed)
        }

        let operationName = Self.directoryPrefix + UUID().uuidString.lowercased()
        let directory = root.appendingPathComponent(operationName, isDirectory: true)
        var rootDescriptor: LocalNotificationStagingFileDescriptor?
        var operationDescriptor: LocalNotificationStagingFileDescriptor?
        var owner: LocalNotificationStagingOwnership?
        defer {
            if owner == nil {
                if let operationDescriptor { fileSystem.close(operationDescriptor) }
                if let rootDescriptor { fileSystem.close(rootDescriptor) }
            }
        }

        do {
            let openedRoot = try fileSystem.openDirectory(at: root)
            rootDescriptor = openedRoot
            let rootIdentity = try fileSystem.identity(of: openedRoot)

            try fileSystem.createDirectory(named: operationName, in: openedRoot)
            let openedOperation = try fileSystem.openDirectory(named: operationName, in: openedRoot)
            operationDescriptor = openedOperation
            let operationIdentity = try fileSystem.identity(of: openedOperation)
            guard try fileSystem.identity(ofEntryNamed: operationName, in: openedRoot) == operationIdentity else {
                throw StagingSafetyError.replacedDirectory
            }

            let createdOwner = LocalNotificationStagingOwnership(
                fileSystem: fileSystem,
                rootDescriptor: openedRoot,
                rootIdentity: rootIdentity,
                operationDescriptor: openedOperation,
                operationIdentity: operationIdentity,
                operationName: operationName
            )
            owner = createdOwner
            rootDescriptor = nil
            operationDescriptor = nil

            var staged: [LocalNotificationStagedAttachment] = []
            staged.reserveCapacity(attachments.count)
            for attachment in attachments {
                try checkCancellation()
                staged.append(
                    try stage(
                        attachment,
                        requestID: requestID,
                        directory: directory,
                        owner: createdOwner
                    )
                )
            }
            try checkCancellation()
            return staged
        } catch {
            _ = owner?.cleanup()
            if error is CancellationError {
                throw CancellationError()
            }
            if let error = error as? LocalNotificationServiceError {
                throw error
            }
            throw LocalNotificationServiceError.invalidAttachment(firstAttachment.id, .stagingFailed)
        }
    }

    @discardableResult
    func cleanup(
        _ staged: [LocalNotificationStagedAttachment]
    ) -> [LocalNotificationStagingCleanupOutcome] {
        Set(staged.map(\.cleanupOwner)).map { $0.cleanup() }
    }

    static func isSafe(filenameExtension: String) -> Bool {
        let scalars = filenameExtension.unicodeScalars
        return (1...16).contains(scalars.count) && scalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) ||
                (65...90).contains(scalar.value) ||
                (97...122).contains(scalar.value)
        }
    }

    private func validateLogicalAttachments(
        _ attachments: [LocalNotificationAttachment]
    ) throws {
        var identifiers = Set<LocalNotificationAttachmentID>()
        for attachment in attachments {
            guard identifiers.insert(attachment.id).inserted else {
                throw LocalNotificationServiceError.invalidAttachment(attachment.id, .invalidOptions)
            }
            try LocalNotificationValidator.validate(attachment: attachment)
        }
    }

    private func stage(
        _ attachment: LocalNotificationAttachment,
        requestID: LocalNotificationID,
        directory: URL,
        owner: LocalNotificationStagingOwnership
    ) throws -> LocalNotificationStagedAttachment {
        guard Self.isUnambiguousLocalFileURL(attachment.fileURL) else {
            let reason: LocalNotificationAttachmentFailure = attachment.fileURL.isFileURL
                ? .symbolicLink
                : .notFileURL
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, reason)
        }

        let accessedSecurityScope = securityScopeAccessor.startAccessing(attachment.fileURL)
        defer {
            if accessedSecurityScope {
                securityScopeAccessor.stopAccessing(attachment.fileURL)
            }
        }

        let sourceDescriptor: LocalNotificationStagingFileDescriptor
        do {
            sourceDescriptor = try fileSystem.openSourceFile(at: attachment.fileURL)
        } catch let error as LocalNotificationStagingFileSystemError {
            throw LocalNotificationServiceError.invalidAttachment(
                attachment.id,
                Self.failureReason(for: error)
            )
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .unreadable)
        }
        defer { fileSystem.close(sourceDescriptor) }

        guard let mediaKind = mediaTypeResolver.mediaKind(
            for: attachment.fileURL,
            fileTypeHint: attachment.options.typeHint
        ), Self.isSafe(filenameExtension: mediaKind.filenameExtension) else {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .unsupportedType)
        }

        let destinationName = UUID().uuidString.lowercased() + "." + mediaKind.filenameExtension.lowercased()
        let destinationDescriptor: LocalNotificationStagingFileDescriptor
        do {
            destinationDescriptor = try owner.withOperationDescriptor {
                try fileSystem.createFile(named: destinationName, in: $0)
            }
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .stagingFailed)
        }
        defer { fileSystem.close(destinationDescriptor) }
        owner.registerGeneratedFile(destinationName)

        do {
            try copyBytes(from: sourceDescriptor, to: destinationDescriptor)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .stagingFailed)
        }

        let destination = directory.appendingPathComponent(destinationName, isDirectory: false)
        let namespace = try LocalNotificationNamespace()
        let systemAttachment = LocalNotificationSystemAttachment(
            identifier: namespace.physicalAttachmentID(requestID, attachment.id),
            fileURL: destination,
            typeIdentifier: mediaKind.typeIdentifier,
            options: LocalNotificationSystemAttachmentOptions(
                typeHint: attachment.options.typeHint,
                hidesThumbnail: attachment.options.hidesThumbnail,
                thumbnailClippingRect: attachment.options.thumbnailClippingRect,
                thumbnailTime: attachment.options.thumbnailTime
            )
        )
        return LocalNotificationStagedAttachment(
            systemAttachment: systemAttachment,
            typeIdentifier: mediaKind.typeIdentifier,
            cleanupOwner: owner
        )
    }

    private func copyBytes(
        from source: LocalNotificationStagingFileDescriptor,
        to destination: LocalNotificationStagingFileDescriptor
    ) throws {
        while true {
            try checkCancellation()
            let data = try fileSystem.read(from: source, maximumCount: Self.copyBufferSize)
            guard !data.isEmpty else { break }
            var offset = 0
            while offset < data.count {
                try checkCancellation()
                let count = try fileSystem.write(data, fromOffset: offset, to: destination)
                guard count > 0, count <= data.count - offset else {
                    throw LocalNotificationStagingFileSystemError.system(EIO)
                }
                offset += count
            }
        }
        try checkCancellation()
    }

    private func validatedRoot(_ candidate: URL) throws -> URL {
        guard Self.isUnambiguousLocalFileURL(candidate) else {
            throw StagingSafetyError.invalidRoot
        }
        let root = candidate.standardizedFileURL
        let temporaryDirectory = fileManager.temporaryDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard Self.isSameOrDescendant(root, of: temporaryDirectory) else {
            throw StagingSafetyError.invalidRoot
        }
        return root
    }

    private static func isUnambiguousLocalFileURL(_ url: URL) -> Bool {
        guard url.isFileURL,
              url.path.hasPrefix("/"),
              url.host == nil || url.host?.isEmpty == true || url.host == "localhost" else {
            return false
        }
        return url.pathComponents.dropFirst().allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\0")
        }
    }

    private static func isSameOrDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private static func failureReason(
        for error: LocalNotificationStagingFileSystemError
    ) -> LocalNotificationAttachmentFailure {
        switch error {
        case .missing:
            .missing
        case .symbolicLink:
            .symbolicLink
        case .notDirectory, .notRegularFile:
            .notRegularFile
        case .unreadable:
            .unreadable
        case .alreadyExists, .system:
            .stagingFailed
        }
    }
}

private nonisolated enum StagingSafetyError: Error {
    case invalidRoot
    case replacedDirectory
}
