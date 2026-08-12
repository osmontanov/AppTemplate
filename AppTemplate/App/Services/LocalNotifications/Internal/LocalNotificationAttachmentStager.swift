import Foundation
import UniformTypeIdentifiers

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
struct LocalNotificationStagedAttachment: Hashable, Sendable {
    let systemAttachment: LocalNotificationSystemAttachment
    let typeIdentifier: String
    fileprivate let cleanupScope: LocalNotificationAttachmentStager.CleanupScope

    var url: URL { systemAttachment.fileURL }
}

nonisolated
struct LocalNotificationAttachmentStager {
    typealias TemporaryRootFactory = @Sendable (FileManager) throws -> URL
    typealias CopyItem = @Sendable (FileManager, URL, URL) throws -> Void
    typealias CheckCancellation = @Sendable () throws -> Void

    fileprivate struct CleanupScope: Hashable, Sendable {
        let root: URL
        let directory: URL
    }

    private static let directoryPrefix = "LocalNotificationAttachments-"

    private let fileManager: FileManager
    private let temporaryRootFactory: TemporaryRootFactory
    private let mediaTypeResolver: any LocalNotificationMediaTypeResolving
    private let securityScopeAccessor: any LocalNotificationSecurityScopeAccessing
    private let copyItem: CopyItem
    private let checkCancellation: CheckCancellation

    init(
        fileManager: FileManager,
        temporaryRootFactory: @escaping TemporaryRootFactory,
        mediaTypeResolver: any LocalNotificationMediaTypeResolving,
        securityScopeAccessor: any LocalNotificationSecurityScopeAccessing,
        copyItem: @escaping CopyItem = { fileManager, source, destination in
            try fileManager.copyItem(at: source, to: destination)
        },
        checkCancellation: @escaping CheckCancellation = { try Task.checkCancellation() }
    ) {
        self.fileManager = fileManager
        self.temporaryRootFactory = temporaryRootFactory
        self.mediaTypeResolver = mediaTypeResolver
        self.securityScopeAccessor = securityScopeAccessor
        self.copyItem = copyItem
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
            throw LocalNotificationServiceError.invalidAttachment(
                firstAttachment.id,
                .stagingFailed
            )
        }

        let directory = root.appendingPathComponent(
            Self.directoryPrefix + UUID().uuidString.lowercased(),
            isDirectory: true
        ).standardizedFileURL
        let cleanupScope = CleanupScope(root: root, directory: directory)

        do {
            try validateNewStagingDirectory(directory, under: root)
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: nil
            )
            try validateExistingStagingDirectory(cleanupScope)

            var staged: [LocalNotificationStagedAttachment] = []
            staged.reserveCapacity(attachments.count)
            for attachment in attachments {
                try checkCancellation()
                staged.append(
                    try stage(
                        attachment,
                        requestID: requestID,
                        cleanupScope: cleanupScope
                    )
                )
            }
            try checkCancellation()
            return staged
        } catch {
            removeStagingDirectory(cleanupScope)
            if error is CancellationError {
                throw CancellationError()
            }
            if let error = error as? LocalNotificationServiceError {
                throw error
            }
            throw LocalNotificationServiceError.invalidAttachment(
                firstAttachment.id,
                .stagingFailed
            )
        }
    }

    func cleanup(_ staged: [LocalNotificationStagedAttachment]) {
        for cleanupScope in Set(staged.map(\.cleanupScope)) {
            removeStagingDirectory(cleanupScope)
        }
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
                throw LocalNotificationServiceError.invalidAttachment(
                    attachment.id,
                    .invalidOptions
                )
            }
            try LocalNotificationValidator.validate(attachment: attachment)
        }
    }

    private func stage(
        _ attachment: LocalNotificationAttachment,
        requestID: LocalNotificationID,
        cleanupScope: CleanupScope
    ) throws -> LocalNotificationStagedAttachment {
        guard Self.isLocalFileURL(attachment.fileURL) else {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .notFileURL)
        }

        let accessedSecurityScope = securityScopeAccessor.startAccessing(attachment.fileURL)
        defer {
            if accessedSecurityScope {
                securityScopeAccessor.stopAccessing(attachment.fileURL)
            }
        }

        try validateSource(attachment)
        guard let mediaKind = mediaTypeResolver.mediaKind(
            for: attachment.fileURL,
            fileTypeHint: attachment.options.typeHint
        ), Self.isSafe(filenameExtension: mediaKind.filenameExtension) else {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .unsupportedType)
        }

        let destination = cleanupScope.directory.appendingPathComponent(
            UUID().uuidString.lowercased() + "." + mediaKind.filenameExtension.lowercased(),
            isDirectory: false
        ).standardizedFileURL
        guard destination.deletingLastPathComponent() == cleanupScope.directory,
              !fileManager.fileExists(atPath: destination.path) else {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .stagingFailed)
        }

        do {
            try copyItem(fileManager, attachment.fileURL, destination)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .stagingFailed)
        }

        do {
            guard try isRegularNonSymbolicFile(destination) else {
                throw LocalNotificationServiceError.invalidAttachment(attachment.id, .stagingFailed)
            }
        } catch let error as LocalNotificationServiceError {
            throw error
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .stagingFailed)
        }

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
            cleanupScope: cleanupScope
        )
    }

    private func validateSource(_ attachment: LocalNotificationAttachment) throws {
        do {
            if try pathContainsSymbolicLink(attachment.fileURL) {
                throw LocalNotificationServiceError.invalidAttachment(attachment.id, .symbolicLink)
            }
        } catch let error as LocalNotificationServiceError {
            throw error
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .unreadable)
        }

        let url = attachment.fileURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .missing)
        }
        guard !isDirectory.boolValue else {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .notRegularFile)
        }

        do {
            guard try isRegularNonSymbolicFile(url) else {
                throw LocalNotificationServiceError.invalidAttachment(attachment.id, .notRegularFile)
            }
        } catch let error as LocalNotificationServiceError {
            throw error
        } catch {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .unreadable)
        }
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .unreadable)
        }
    }

    private func validatedRoot(_ candidate: URL) throws -> URL {
        guard Self.isLocalFileURL(candidate),
              try !pathContainsSymbolicLink(candidate) else {
            throw StagingSafetyError.invalidRoot
        }
        let root = candidate.standardizedFileURL
        let temporaryDirectory = fileManager.temporaryDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard root.path.hasPrefix("/"),
              Self.isSameOrDescendant(root, of: temporaryDirectory),
              try !pathContainsSymbolicLink(temporaryDirectory),
              try isDirectory(temporaryDirectory),
              try !pathContainsSymbolicLink(root),
              try isDirectory(root) else {
            throw StagingSafetyError.invalidRoot
        }
        return root
    }

    private func validateNewStagingDirectory(_ directory: URL, under root: URL) throws {
        let standardizedDirectory = directory.standardizedFileURL
        guard standardizedDirectory.deletingLastPathComponent() == root,
              Self.isGeneratedDirectoryName(standardizedDirectory.lastPathComponent),
              !fileManager.fileExists(atPath: standardizedDirectory.path) else {
            throw StagingSafetyError.invalidDirectory
        }
    }

    private func validateExistingStagingDirectory(_ cleanupScope: CleanupScope) throws {
        let root = try validatedRoot(cleanupScope.root)
        guard cleanupScope.directory.standardizedFileURL.deletingLastPathComponent() == root,
              Self.isGeneratedDirectoryName(cleanupScope.directory.lastPathComponent),
              try !pathContainsSymbolicLink(cleanupScope.directory),
              try isDirectory(cleanupScope.directory) else {
            throw StagingSafetyError.invalidDirectory
        }
    }

    private func removeStagingDirectory(_ cleanupScope: CleanupScope) {
        guard (try? validateExistingStagingDirectory(cleanupScope)) != nil,
              (try? directoryTreeContainsSymbolicLink(cleanupScope.directory)) == false else {
            return
        }
        try? fileManager.removeItem(at: cleanupScope.directory)
    }

    private func directoryTreeContainsSymbolicLink(_ directory: URL) throws -> Bool {
        for child in try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ) {
            if try pathContainsSymbolicLink(child) {
                return true
            }
            if try isDirectory(child), try directoryTreeContainsSymbolicLink(child) {
                return true
            }
        }
        return false
    }

    private func pathContainsSymbolicLink(_ url: URL) throws -> Bool {
        guard url.isFileURL else { return false }
        var path = "/"
        for component in url.pathComponents.dropFirst() {
            guard component != ".", component != ".." else { return true }
            path = URL(fileURLWithPath: path, isDirectory: true)
                .appendingPathComponent(component)
                .path
            do {
                _ = try fileManager.destinationOfSymbolicLink(atPath: path)
                return true
            } catch CocoaError.fileReadNoSuchFile {
                continue
            } catch CocoaError.fileReadInvalidFileName {
                continue
            } catch {
                let attributes = try? fileManager.attributesOfItem(atPath: path)
                if attributes?[.type] == nil {
                    continue
                }
            }
        }
        return false
    }

    private func isRegularNonSymbolicFile(_ url: URL) throws -> Bool {
        guard try !pathContainsSymbolicLink(url) else { return false }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private func isDirectory(_ url: URL) throws -> Bool {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.type] as? FileAttributeType == .typeDirectory
    }

    private static func isLocalFileURL(_ url: URL) -> Bool {
        url.isFileURL && (url.host == nil || url.host?.isEmpty == true || url.host == "localhost")
    }

    private static func isGeneratedDirectoryName(_ value: String) -> Bool {
        guard value.hasPrefix(directoryPrefix) else { return false }
        return UUID(uuidString: String(value.dropFirst(directoryPrefix.count))) != nil
    }

    private static func isSameOrDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }
}

private nonisolated enum StagingSafetyError: Error {
    case invalidRoot
    case invalidDirectory
}
