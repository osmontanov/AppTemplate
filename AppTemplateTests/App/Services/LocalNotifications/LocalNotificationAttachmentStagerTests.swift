import CoreGraphics
import Foundation
import Synchronization
import Testing
@testable import AppTemplate

nonisolated
struct LocalNotificationAttachmentStagerTests {
    @Test
    func stagingCopiesARealPNGWithoutMovingOrRenamingTheSource() throws {
        let fixture = try AttachmentFileFixture(fileName: "private-user-name.png")
        defer { fixture.cleanup() }
        let stager = fixture.makeStager()
        let attachment = try fixture.attachment(
            id: "hero",
            options: .init(typeHint: "public.png")
        )

        let staged = try stager.stage([attachment], requestID: .init("request"))
        let descriptor = try #require(staged.first)
        defer { stager.cleanup(staged) }

        #expect(staged.count == 1)
        #expect(descriptor.url != fixture.sourceURL)
        #expect(descriptor.url.deletingLastPathComponent().deletingLastPathComponent() == fixture.stagingRoot)
        #expect(descriptor.url.lastPathComponent != fixture.sourceURL.lastPathComponent)
        #expect(!descriptor.url.path.contains("private-user-name"))
        #expect(!descriptor.url.path.contains("request"))
        #expect(!descriptor.url.path.contains("hero"))
        #expect(descriptor.url.pathExtension == "png")
        #expect(descriptor.typeIdentifier == "public.png")
        #expect(descriptor.systemAttachment.identifier == "AppTemplate.LocalNotification.attachment.cmVxdWVzdA.aGVybw")
        #expect(descriptor.systemAttachment.fileURL == descriptor.url)
        #expect(descriptor.systemAttachment.options.typeHint == "public.png")
        #expect(FileManager.default.fileExists(atPath: fixture.sourceURL.path))
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
        #expect(try Data(contentsOf: descriptor.url) == AttachmentFileFixture.onePixelPNG)
    }

    @Test
    func separateStagingOperationsUseSeparateRequestDirectories() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let stager = fixture.makeStager()
        let attachment = try fixture.attachment(id: "hero")

        let first = try stager.stage([attachment], requestID: .init("first"))
        defer { stager.cleanup(first) }
        let second = try stager.stage([attachment], requestID: .init("second"))
        defer { stager.cleanup(second) }

        #expect(first.first?.url.deletingLastPathComponent() != second.first?.url.deletingLastPathComponent())
    }

    @Test
    func nonFileURLIsRejectedWithoutCreatingAStagingDirectory() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("remote")
        let attachment = LocalNotificationAttachment(
            id: identifier,
            fileURL: try #require(URL(string: "https://example.invalid/private.png"))
        )

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .notFileURL)) {
            _ = try fixture.makeStager().stage([attachment], requestID: .init("request"))
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func missingFileIsRejectedAndTheErrorContainsOnlyTheLogicalIDAndClosedReason() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("missing")
        let missing = fixture.sourceDirectory.appendingPathComponent("secret-missing.png")
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: missing)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .missing)) {
            _ = try fixture.makeStager().stage([attachment], requestID: .init("request"))
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func directoryIsRejectedAsNotARegularFile() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("directory")
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: fixture.sourceDirectory)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .notRegularFile)) {
            _ = try fixture.makeStager().stage([attachment], requestID: .init("request"))
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func symbolicLinkFileIsRejectedWithoutReadingItsTarget() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("link")
        let link = fixture.sourceDirectory.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.sourceURL)
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: link)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .symbolicLink)) {
            _ = try fixture.makeStager().stage([attachment], requestID: .init("request"))
        }
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func symbolicLinkInTheSourcePathIsRejectedWithoutTraversal() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("nested-link")
        let linkedDirectory = fixture.root.appendingPathComponent("linked-source", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: fixture.sourceDirectory
        )
        let attachment = LocalNotificationAttachment(
            id: identifier,
            fileURL: linkedDirectory.appendingPathComponent(fixture.sourceURL.lastPathComponent)
        )

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .symbolicLink)) {
            _ = try fixture.makeStager().stage([attachment], requestID: .init("request"))
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func lexicalParentComponentCannotHideASymbolicLinkHop() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("hidden-link")
        let linkedDirectory = fixture.root.appendingPathComponent("linked-source", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: fixture.sourceDirectory
        )
        let lexicalURL = URL(
            fileURLWithPath: linkedDirectory.path + "/../source/" + fixture.sourceURL.lastPathComponent
        )
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: lexicalURL)
        let stager = fixture.makeStager()

        do {
            let unexpectedlyStaged = try stager.stage([attachment], requestID: .init("request"))
            stager.cleanup(unexpectedlyStaged)
            Issue.record("Expected lexical symlink traversal to be rejected")
        } catch {
            #expect(error as? LocalNotificationServiceError == .invalidAttachment(identifier, .symbolicLink))
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func unreadableFileIsRejected() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("unreadable")
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0))],
            ofItemAtPath: fixture.sourceURL.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))],
                ofItemAtPath: fixture.sourceURL.path
            )
        }
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: fixture.sourceURL)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .unreadable)) {
            _ = try fixture.makeStager().stage([attachment], requestID: .init("request"))
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func unsupportedMediaAndUnsupportedHintAreRejected() throws {
        let fixture = try AttachmentFileFixture(fileName: "notes.txt", bytes: Data("hello".utf8))
        defer { fixture.cleanup() }
        let identifier = try LocalNotificationAttachmentID("unsupported")
        let unsupportedFile = LocalNotificationAttachment(id: identifier, fileURL: fixture.sourceURL)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .unsupportedType)) {
            _ = try fixture.makeStager().stage([unsupportedFile], requestID: .init("request"))
        }

        let pngFixture = try AttachmentFileFixture()
        defer { pngFixture.cleanup() }
        let unsupportedHint = LocalNotificationAttachment(
            id: identifier,
            fileURL: pngFixture.sourceURL,
            options: .init(typeHint: "public.plain-text")
        )
        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .unsupportedType)) {
            _ = try pngFixture.makeStager().stage([unsupportedHint], requestID: .init("request"))
        }
    }

    @Test
    func duplicateLogicalAttachmentIDIsRejectedBeforeStaging() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let attachment = try fixture.attachment(id: "duplicate")

        #expect(throws: LocalNotificationServiceError.invalidAttachment(attachment.id, .invalidOptions)) {
            _ = try fixture.makeStager().stage(
                [attachment, attachment],
                requestID: .init("request")
            )
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test(arguments: [
        LocalNotificationAttachmentOptions(
            thumbnailClippingRect: CGRect(x: 0.8, y: 0, width: 0.3, height: 1)
        ),
        LocalNotificationAttachmentOptions(thumbnailTime: -0.001),
        LocalNotificationAttachmentOptions(thumbnailTime: .infinity)
    ])
    func invalidNumericOptionsAreRejectedBeforeStaging(
        _ options: LocalNotificationAttachmentOptions
    ) throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let attachment = try fixture.attachment(id: "invalid-options", options: options)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(attachment.id, .invalidOptions)) {
            _ = try fixture.makeStager().stage([attachment], requestID: .init("request"))
        }
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test(arguments: [
        LocalNotificationMediaKind.audio(typeIdentifier: "public.mpeg-4-audio", filenameExtension: "m4a"),
        LocalNotificationMediaKind.movie(typeIdentifier: "com.apple.quicktime-movie", filenameExtension: "mov")
    ])
    func injectedResolverStagesConformingAudioAndMovieDescriptors(
        _ mediaKind: LocalNotificationMediaKind
    ) throws {
        let fixture = try AttachmentFileFixture(fileName: "caller.data", bytes: Data([0x01, 0x02]))
        defer { fixture.cleanup() }
        let stager = fixture.makeStager(mediaResolver: FixedMediaResolver(mediaKind))
        let attachment = try fixture.attachment(
            id: "media",
            options: .init(typeHint: mediaKind.typeIdentifier)
        )

        let staged = try stager.stage([attachment], requestID: .init("request"))
        defer { stager.cleanup(staged) }
        let descriptor = try #require(staged.first)

        #expect(descriptor.typeIdentifier == mediaKind.typeIdentifier)
        #expect(descriptor.url.pathExtension == mediaKind.filenameExtension)
        #expect(try Data(contentsOf: descriptor.url) == Data([0x01, 0x02]))
    }

    @Test
    func securityScopedAccessIsActiveForTheCopyAndBalancedOnSuccess() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let access = RecordingSecurityScopeAccessor(startSucceeds: true)
        let sourceURL = fixture.sourceURL
        let fileSystem = ControlledStagingFileSystem(
            behavior: .afterSourceOpen {
                #expect(access.isActive(sourceURL))
            }
        )
        let stager = fixture.makeStager(
            securityScopeAccessor: access,
            fileSystem: fileSystem
        )
        let attachment = try fixture.attachment(id: "scoped")

        let staged = try stager.stage([attachment], requestID: .init("request"))
        defer { stager.cleanup(staged) }

        #expect(access.startedURLs == [fixture.sourceURL])
        #expect(access.stoppedURLs == [fixture.sourceURL])
        #expect(!access.isActive(fixture.sourceURL))
    }

    @Test
    func securityScopedAccessIsBalancedWhenCopyingFails() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let access = RecordingSecurityScopeAccessor(startSucceeds: true)
        let identifier = try LocalNotificationAttachmentID("copy-failure")
        let stager = fixture.makeStager(
            securityScopeAccessor: access,
            fileSystem: ControlledStagingFileSystem(behavior: .readFailure)
        )
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: fixture.sourceURL)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .stagingFailed)) {
            _ = try stager.stage([attachment], requestID: .init("request"))
        }
        #expect(access.startedURLs == [fixture.sourceURL])
        #expect(access.stoppedURLs == [fixture.sourceURL])
        #expect(!access.isActive(fixture.sourceURL))
        #expect(try fixture.stagedItems().isEmpty)
    }

    @Test
    func secondCopyFailureRemovesOnlyThisOperationsPartialDirectory() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let secondSource = fixture.sourceDirectory.appendingPathComponent("second.png")
        try AttachmentFileFixture.onePixelPNG.write(to: secondSource)
        let fileSystem = ControlledStagingFileSystem(
            behavior: .partialWriteFailure(destinationOrdinal: 2)
        )
        let stager = fixture.makeStager(fileSystem: fileSystem)
        let first = try fixture.attachment(id: "first")
        let secondID = try LocalNotificationAttachmentID("second")
        let second = LocalNotificationAttachment(id: secondID, fileURL: secondSource)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(secondID, .stagingFailed)) {
            _ = try stager.stage([first, second], requestID: .init("request"))
        }

        #expect(fileSystem.partialBytesWritten == 4)
        #expect(try fixture.stagedItems().isEmpty)
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
        #expect(try Data(contentsOf: secondSource) == AttachmentFileFixture.onePixelPNG)
        #expect(FileManager.default.fileExists(atPath: fixture.sourceDirectory.path))
        #expect(FileManager.default.fileExists(atPath: fixture.stagingRoot.path))
    }

    @Test
    func cancellationAfterPartialDestinationWriteCleansTheOwnedOperation() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let cancellation = CancellationFlag()
        let fileSystem = ControlledStagingFileSystem(
            behavior: .partialWriteCancellation(
                destinationOrdinal: 1,
                cancellation: cancellation
            )
        )
        let stager = fixture.makeStager(
            fileSystem: fileSystem,
            checkCancellation: cancellation.check
        )
        let attachment = try fixture.attachment(id: "partial-cancel")

        #expect(throws: CancellationError.self) {
            _ = try stager.stage([attachment], requestID: .init("request"))
        }

        #expect(fileSystem.partialBytesWritten == 4)
        #expect(try fixture.stagedItems().isEmpty)
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
    }

    @Test
    func openedSourceDescriptorCannotBeRedirectedByIntermediateReplacement() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let sourceDirectory = fixture.sourceDirectory
        let sourceURL = fixture.sourceURL
        let movedSourceDirectory = fixture.root.appendingPathComponent(
            "opened-source",
            isDirectory: true
        )
        let replacementDirectory = fixture.root.appendingPathComponent(
            "replacement-source",
            isDirectory: true
        )
        let replacementBytes = Data("replacement bytes".utf8)
        try FileManager.default.createDirectory(
            at: replacementDirectory,
            withIntermediateDirectories: false
        )
        try replacementBytes.write(
            to: replacementDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        )
        let fileSystem = ControlledStagingFileSystem(
            behavior: .afterSourceOpen {
                try FileManager.default.moveItem(at: sourceDirectory, to: movedSourceDirectory)
                try FileManager.default.createSymbolicLink(
                    at: sourceDirectory,
                    withDestinationURL: replacementDirectory
                )
            }
        )
        let stager = fixture.makeStager(fileSystem: fileSystem)
        let attachment = try fixture.attachment(id: "stable-source")

        let staged = try stager.stage([attachment], requestID: .init("request"))
        defer { stager.cleanup(staged) }
        let descriptor = try #require(staged.first)

        #expect(try Data(contentsOf: descriptor.url) == AttachmentFileFixture.onePixelPNG)
        #expect(try Data(contentsOf: sourceURL) == replacementBytes)
        #expect(
            try Data(contentsOf: movedSourceDirectory.appendingPathComponent(sourceURL.lastPathComponent)) ==
                AttachmentFileFixture.onePixelPNG
        )
    }

    @Test
    func failedExclusiveCreateNeverClaimsOrDeletesTheForeignDirectory() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let fileSystem = ControlledStagingFileSystem(behavior: .foreignDirectoryWins)
        let stager = fixture.makeStager(fileSystem: fileSystem)
        let attachment = try fixture.attachment(id: "foreign-create")

        #expect(throws: LocalNotificationServiceError.invalidAttachment(attachment.id, .stagingFailed)) {
            _ = try stager.stage([attachment], requestID: .init("request"))
        }

        let foreignDirectory = try #require(fixture.stagedItems().first)
        #expect(try fixture.stagedItems().count == 1)
        #expect(
            try Data(contentsOf: foreignDirectory.appendingPathComponent("foreign-sentinel")) ==
                Data("foreign".utf8)
        )
    }

    @Test
    func cancellationBetweenFilesRemovesPartialCopiesAndPreservesEverySource() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let secondSource = fixture.sourceDirectory.appendingPathComponent("second.png")
        try AttachmentFileFixture.onePixelPNG.write(to: secondSource)
        let cancellation = CancellationFlag()
        let fileSystem = ControlledStagingFileSystem(
            behavior: .cancelAfterSourceEOF(sourceOrdinal: 1, cancellation: cancellation)
        )
        let stager = fixture.makeStager(
            fileSystem: fileSystem,
            checkCancellation: cancellation.check
        )
        let first = try fixture.attachment(id: "first")
        let second = LocalNotificationAttachment(
            id: try .init("second"),
            fileURL: secondSource
        )

        #expect(throws: CancellationError.self) {
            _ = try stager.stage([first, second], requestID: .init("request"))
        }

        #expect(try fixture.stagedItems().isEmpty)
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
        #expect(try Data(contentsOf: secondSource) == AttachmentFileFixture.onePixelPNG)
    }

    @Test
    func cancellationAfterTheLastCopyAndBeforeReturnRemovesTheStagedDirectory() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let cancellation = CancellationFlag()
        let fileSystem = ControlledStagingFileSystem(
            behavior: .cancelAfterSourceEOF(sourceOrdinal: 1, cancellation: cancellation)
        )
        let stager = fixture.makeStager(
            fileSystem: fileSystem,
            checkCancellation: cancellation.check
        )
        let attachment = try fixture.attachment(id: "only")

        #expect(throws: CancellationError.self) {
            _ = try stager.stage([attachment], requestID: .init("request"))
        }

        #expect(try fixture.stagedItems().isEmpty)
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
    }

    @Test
    func explicitCleanupIsScopedAndIdempotent() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let unrelated = fixture.stagingRoot.appendingPathComponent("unrelated-owner", isDirectory: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: false)
        let stager = fixture.makeStager()
        let attachment = try fixture.attachment(id: "cleanup")
        let staged = try stager.stage([attachment], requestID: .init("request"))
        let requestDirectory = try #require(staged.first?.url.deletingLastPathComponent())

        #expect(FileManager.default.fileExists(atPath: requestDirectory.path))
        #expect(stager.cleanup(staged) == [.removed])
        #expect(stager.cleanup(staged) == [.alreadyCleaned])

        #expect(!FileManager.default.fileExists(atPath: requestDirectory.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
        #expect(FileManager.default.fileExists(atPath: fixture.stagingRoot.path))
    }

    @Test
    func rootPathReplacementCannotRedirectDescriptorAnchoredCleanup() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let stager = fixture.makeStager()
        let attachment = try fixture.attachment(id: "root-replacement")
        let staged = try stager.stage([attachment], requestID: .init("request"))
        let descriptor = try #require(staged.first)
        let operationName = descriptor.url.deletingLastPathComponent().lastPathComponent
        let movedOwnedRoot = fixture.root.appendingPathComponent("owned-root", isDirectory: true)
        let replacementSentinel = fixture.stagingRoot.appendingPathComponent("replacement-sentinel")

        try FileManager.default.moveItem(at: fixture.stagingRoot, to: movedOwnedRoot)
        try FileManager.default.createDirectory(
            at: fixture.stagingRoot,
            withIntermediateDirectories: false
        )
        try Data("replacement".utf8).write(to: replacementSentinel)

        #expect(stager.cleanup(staged) == [.removed])
        #expect(
            !FileManager.default.fileExists(
                atPath: movedOwnedRoot.appendingPathComponent(operationName).path
            )
        )
        #expect(try Data(contentsOf: replacementSentinel) == Data("replacement".utf8))
    }

    @Test
    func operationSymlinkReplacementIsNeverFollowedAndOwnedContentsAreUnlinked() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let stager = fixture.makeStager()
        let attachment = try fixture.attachment(id: "operation-replacement")
        let staged = try stager.stage([attachment], requestID: .init("request"))
        let descriptor = try #require(staged.first)
        let operationDirectory = descriptor.url.deletingLastPathComponent()
        let movedOwnedDirectory = fixture.root.appendingPathComponent("moved-owned", isDirectory: true)
        let targetDirectory = fixture.root.appendingPathComponent("symlink-target", isDirectory: true)
        let targetSentinel = targetDirectory.appendingPathComponent("target-sentinel")
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: false)
        try Data("target".utf8).write(to: targetSentinel)
        try FileManager.default.moveItem(at: operationDirectory, to: movedOwnedDirectory)
        try FileManager.default.createSymbolicLink(
            at: operationDirectory,
            withDestinationURL: targetDirectory
        )

        #expect(stager.cleanup(staged) == [.replacementDetected])
        #expect(FileManager.default.fileExists(atPath: operationDirectory.path))
        #expect(try Data(contentsOf: targetSentinel) == Data("target".utf8))
        #expect(
            !FileManager.default.fileExists(
                atPath: movedOwnedDirectory.appendingPathComponent(descriptor.url.lastPathComponent).path
            )
        )
        #expect(FileManager.default.fileExists(atPath: movedOwnedDirectory.path))
    }

    @Test
    func operationReplacementDuringCleanupPreservesTheUnrelatedDirectory() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let fileSystem = ControlledStagingFileSystem(behavior: .cleanupIdentityHook)
        let stager = fixture.makeStager(fileSystem: fileSystem)
        let attachment = try fixture.attachment(id: "during-cleanup")
        let staged = try stager.stage([attachment], requestID: .init("request"))
        let descriptor = try #require(staged.first)
        let operationDirectory = descriptor.url.deletingLastPathComponent()
        let movedOwnedDirectory = fixture.root.appendingPathComponent(
            "moved-during-cleanup",
            isDirectory: true
        )
        let replacementSentinel = operationDirectory.appendingPathComponent("unrelated-sentinel")
        fileSystem.armCleanupHook {
            try FileManager.default.moveItem(at: operationDirectory, to: movedOwnedDirectory)
            try FileManager.default.createDirectory(
                at: operationDirectory,
                withIntermediateDirectories: false
            )
            try Data("unrelated".utf8).write(to: replacementSentinel)
        }

        #expect(stager.cleanup(staged) == [.replacementDetected])
        #expect(try Data(contentsOf: replacementSentinel) == Data("unrelated".utf8))
        #expect(
            !FileManager.default.fileExists(
                atPath: movedOwnedDirectory.appendingPathComponent(descriptor.url.lastPathComponent).path
            )
        )
    }

    @Test
    func symbolicLinkTemporaryRootIsRejectedWithoutTouchingItsTarget() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let linkedRoot = fixture.root.appendingPathComponent("linked-staging", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: fixture.stagingRoot)
        let identifier = try LocalNotificationAttachmentID("unsafe-root")
        let stager = LocalNotificationAttachmentStager(
            fileManager: .default,
            temporaryRootFactory: { _ in linkedRoot },
            mediaTypeResolver: UniformTypeIdentifiersLocalNotificationMediaResolver(),
            securityScopeAccessor: FixedSecurityScopeAccessor(startSucceeds: false)
        )
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: fixture.sourceURL)

        #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, .stagingFailed)) {
            _ = try stager.stage([attachment], requestID: .init("request"))
        }
        #expect(try fixture.stagedItems().isEmpty)
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
    }

    @Test
    func lexicalParentComponentCannotHideASymbolicLinkInTheTemporaryRoot() throws {
        let fixture = try AttachmentFileFixture()
        defer { fixture.cleanup() }
        let linkedRoot = fixture.root.appendingPathComponent("linked-staging", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: fixture.stagingRoot)
        let lexicalRoot = URL(
            fileURLWithPath: linkedRoot.path + "/../" + fixture.stagingRoot.lastPathComponent
        )
        let identifier = try LocalNotificationAttachmentID("hidden-root-link")
        let stager = LocalNotificationAttachmentStager(
            fileManager: .default,
            temporaryRootFactory: { _ in lexicalRoot },
            mediaTypeResolver: UniformTypeIdentifiersLocalNotificationMediaResolver(),
            securityScopeAccessor: FixedSecurityScopeAccessor(startSucceeds: false)
        )
        let attachment = LocalNotificationAttachment(id: identifier, fileURL: fixture.sourceURL)

        do {
            let unexpectedlyStaged = try stager.stage([attachment], requestID: .init("request"))
            stager.cleanup(unexpectedlyStaged)
            Issue.record("Expected lexical temporary-root symlink traversal to be rejected")
        } catch {
            #expect(error as? LocalNotificationServiceError == .invalidAttachment(identifier, .stagingFailed))
        }
        #expect(try fixture.stagedItems().isEmpty)
        #expect(try Data(contentsOf: fixture.sourceURL) == AttachmentFileFixture.onePixelPNG)
    }
}

private nonisolated final class AttachmentFileFixture {
    static let onePixelPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nYQAAAAASUVORK5CYII="
    )!

    let root: URL
    let sourceDirectory: URL
    let stagingRoot: URL
    let sourceURL: URL

    init(
        fileName: String = "source.png",
        bytes: Data = AttachmentFileFixture.onePixelPNG
    ) throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
        root = temporaryDirectory.appendingPathComponent(
            "AppTemplate-LocalNotificationAttachmentStagerTests-\(UUID().uuidString)",
            isDirectory: true
        )
        sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        stagingRoot = root.appendingPathComponent("staging", isDirectory: true)
        sourceURL = sourceDirectory.appendingPathComponent(fileName)

        try fileManager.createDirectory(at: root, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: false)
        try bytes.write(to: sourceURL, options: .withoutOverwriting)

        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let stagingValues = try stagingRoot.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard root.isFileURL,
              root.standardizedFileURL.deletingLastPathComponent() == temporaryDirectory,
              rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true,
              stagingValues.isDirectory == true,
              stagingValues.isSymbolicLink != true else {
            throw FixtureError.invalidTemporaryRoot
        }
    }

    func attachment(
        id: String,
        options: LocalNotificationAttachmentOptions = .init()
    ) throws -> LocalNotificationAttachment {
        LocalNotificationAttachment(
            id: try LocalNotificationAttachmentID(id),
            fileURL: sourceURL,
            options: options
        )
    }

    func makeStager(
        mediaResolver: any LocalNotificationMediaTypeResolving = UniformTypeIdentifiersLocalNotificationMediaResolver(),
        securityScopeAccessor: any LocalNotificationSecurityScopeAccessing = FixedSecurityScopeAccessor(startSucceeds: false),
        fileSystem: any LocalNotificationStagingFileSystem = POSIXLocalNotificationStagingFileSystem(),
        checkCancellation: @escaping LocalNotificationAttachmentStager.CheckCancellation = {
            try Task.checkCancellation()
        }
    ) -> LocalNotificationAttachmentStager {
        LocalNotificationAttachmentStager(
            fileManager: .default,
            temporaryRootFactory: { [stagingRoot] _ in stagingRoot },
            mediaTypeResolver: mediaResolver,
            securityScopeAccessor: securityScopeAccessor,
            fileSystem: fileSystem,
            checkCancellation: checkCancellation
        )
    }

    func stagedItems() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: stagingRoot,
            includingPropertiesForKeys: nil
        )
    }

    func cleanup() {
        guard root.standardizedFileURL.path.contains("AppTemplate-LocalNotificationAttachmentStagerTests-") else {
            return
        }
        try? FileManager.default.removeItem(at: root)
    }
}

private nonisolated struct FixedMediaResolver: LocalNotificationMediaTypeResolving {
    let mediaKind: LocalNotificationMediaKind

    init(_ mediaKind: LocalNotificationMediaKind) {
        self.mediaKind = mediaKind
    }

    func mediaKind(for _: URL, fileTypeHint _: String?) -> LocalNotificationMediaKind? {
        mediaKind
    }
}

private nonisolated struct FixedSecurityScopeAccessor: LocalNotificationSecurityScopeAccessing {
    let startSucceeds: Bool

    func startAccessing(_ url: URL) -> Bool {
        _ = url
        return startSucceeds
    }

    func stopAccessing(_ url: URL) {
        _ = url
    }
}

private nonisolated final class RecordingSecurityScopeAccessor: LocalNotificationSecurityScopeAccessing, Sendable {
    private struct State: Sendable {
        var startedURLs: [URL] = []
        var stoppedURLs: [URL] = []
        var activeURLs: [URL: Int] = [:]
    }

    private let startSucceeds: Bool
    private let state = Mutex(State())

    init(startSucceeds: Bool) {
        self.startSucceeds = startSucceeds
    }

    var startedURLs: [URL] {
        state.withLock(\.startedURLs)
    }

    var stoppedURLs: [URL] {
        state.withLock(\.stoppedURLs)
    }

    func isActive(_ url: URL) -> Bool {
        state.withLock { ($0.activeURLs[url] ?? 0) > 0 }
    }

    func startAccessing(_ url: URL) -> Bool {
        state.withLock {
            $0.startedURLs.append(url)
            if startSucceeds {
                $0.activeURLs[url, default: 0] += 1
            }
        }
        return startSucceeds
    }

    func stopAccessing(_ url: URL) {
        state.withLock {
            $0.stoppedURLs.append(url)
            $0.activeURLs[url, default: 0] -= 1
        }
    }
}

private nonisolated final class CancellationFlag: Sendable {
    private let cancelled = Mutex(false)

    func cancel() {
        cancelled.withLock { $0 = true }
    }

    func check() throws {
        if cancelled.withLock({ $0 }) {
            throw CancellationError()
        }
    }
}

private nonisolated final class ControlledStagingFileSystem: LocalNotificationStagingFileSystem, Sendable {
    enum Behavior: Sendable {
        case afterSourceOpen(@Sendable () throws -> Void)
        case readFailure
        case partialWriteFailure(destinationOrdinal: Int)
        case partialWriteCancellation(
            destinationOrdinal: Int,
            cancellation: CancellationFlag
        )
        case cancelAfterSourceEOF(
            sourceOrdinal: Int,
            cancellation: CancellationFlag
        )
        case foreignDirectoryWins
        case cleanupIdentityHook
    }

    private struct State: Sendable {
        var sourceOrdinal = 0
        var destinationOrdinal = 0
        var cancellationSource: LocalNotificationStagingFileDescriptor?
        var partialDestination: LocalNotificationStagingFileDescriptor?
        var didWritePartialBytes = false
        var partialBytesWritten = 0
        var cleanupHook: (@Sendable () throws -> Void)?
    }

    private let behavior: Behavior
    private let base = POSIXLocalNotificationStagingFileSystem()
    private let state = Mutex(State())

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    var partialBytesWritten: Int {
        state.withLock(\.partialBytesWritten)
    }

    func armCleanupHook(_ hook: @escaping @Sendable () throws -> Void) {
        state.withLock { $0.cleanupHook = hook }
    }

    func openDirectory(at url: URL) throws -> LocalNotificationStagingFileDescriptor {
        try base.openDirectory(at: url)
    }

    func createDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws {
        guard case .foreignDirectoryWins = behavior else {
            try base.createDirectory(named: name, in: parent)
            return
        }

        try base.createDirectory(named: name, in: parent)
        let directory = try base.openDirectory(named: name, in: parent)
        defer { base.close(directory) }
        let sentinel = try base.createFile(named: "foreign-sentinel", in: directory)
        defer { base.close(sentinel) }
        let bytes = Data("foreign".utf8)
        var offset = 0
        while offset < bytes.count {
            offset += try base.write(bytes, fromOffset: offset, to: sentinel)
        }
        try base.createDirectory(named: name, in: parent)
    }

    func openDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationStagingFileDescriptor {
        try base.openDirectory(named: name, in: parent)
    }

    func openSourceFile(at url: URL) throws -> LocalNotificationStagingFileDescriptor {
        let descriptor = try base.openSourceFile(at: url)
        do {
            let ordinal = state.withLock {
                $0.sourceOrdinal += 1
                return $0.sourceOrdinal
            }
            switch behavior {
            case let .afterSourceOpen(action):
                try action()
            case let .cancelAfterSourceEOF(sourceOrdinal, _):
                if ordinal == sourceOrdinal {
                    state.withLock { $0.cancellationSource = descriptor }
                }
            default:
                break
            }
            return descriptor
        } catch {
            base.close(descriptor)
            throw error
        }
    }

    func createFile(
        named name: String,
        in directory: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationStagingFileDescriptor {
        let descriptor = try base.createFile(named: name, in: directory)
        let ordinal = state.withLock {
            $0.destinationOrdinal += 1
            return $0.destinationOrdinal
        }
        switch behavior {
        case let .partialWriteFailure(destinationOrdinal),
             let .partialWriteCancellation(destinationOrdinal, _):
            if ordinal == destinationOrdinal {
                state.withLock { $0.partialDestination = descriptor }
            }
        default:
            break
        }
        return descriptor
    }

    func identity(
        of descriptor: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationFileIdentity {
        try base.identity(of: descriptor)
    }

    func identity(
        ofEntryNamed name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws -> LocalNotificationFileIdentity? {
        if case .cleanupIdentityHook = behavior {
            let hook = state.withLock { state -> (@Sendable () throws -> Void)? in
                defer { state.cleanupHook = nil }
                return state.cleanupHook
            }
            try hook?()
        }
        return try base.identity(ofEntryNamed: name, in: parent)
    }

    func read(
        from descriptor: LocalNotificationStagingFileDescriptor,
        maximumCount: Int
    ) throws -> Data {
        if case .readFailure = behavior {
            throw PrivateCopyError.secretPath
        }
        let data = try base.read(from: descriptor, maximumCount: maximumCount)
        if case let .cancelAfterSourceEOF(_, cancellation) = behavior,
           data.isEmpty,
           state.withLock({ $0.cancellationSource == descriptor }) {
            cancellation.cancel()
        }
        return data
    }

    func write(
        _ data: Data,
        fromOffset offset: Int,
        to descriptor: LocalNotificationStagingFileDescriptor
    ) throws -> Int {
        let isPartialDestination = state.withLock { $0.partialDestination == descriptor }
        guard isPartialDestination else {
            return try base.write(data, fromOffset: offset, to: descriptor)
        }

        let didWritePartialBytes = state.withLock(\.didWritePartialBytes)
        if didWritePartialBytes {
            if case .partialWriteFailure = behavior {
                throw PrivateCopyError.secretPath
            }
            return try base.write(data, fromOffset: offset, to: descriptor)
        }

        let end = min(offset + 4, data.count)
        let partialData = data.subdata(in: offset..<end)
        let written = try base.write(partialData, fromOffset: 0, to: descriptor)
        state.withLock {
            $0.didWritePartialBytes = true
            $0.partialBytesWritten += written
        }
        if case let .partialWriteCancellation(_, cancellation) = behavior {
            cancellation.cancel()
        }
        return written
    }

    func unlinkFile(
        named name: String,
        in directory: LocalNotificationStagingFileDescriptor
    ) throws {
        try base.unlinkFile(named: name, in: directory)
    }

    func unlinkDirectory(
        named name: String,
        in parent: LocalNotificationStagingFileDescriptor
    ) throws {
        try base.unlinkDirectory(named: name, in: parent)
    }

    func close(_ descriptor: LocalNotificationStagingFileDescriptor) {
        base.close(descriptor)
    }
}

private nonisolated enum PrivateCopyError: Error {
    case secretPath
}

private nonisolated enum FixtureError: Error {
    case invalidTemporaryRoot
}
