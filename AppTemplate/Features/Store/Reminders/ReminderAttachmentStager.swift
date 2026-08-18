import Foundation
import UniformTypeIdentifiers

nonisolated
struct StagedReminderAttachment: Sendable {
    let attachment: LocalNotificationAttachment
    private let cleanupOperation: @Sendable () -> Void

    init(
        attachment: LocalNotificationAttachment,
        cleanup: @escaping @Sendable () -> Void
    ) {
        self.attachment = attachment
        cleanupOperation = cleanup
    }

    func cleanup() {
        cleanupOperation()
    }
}

actor ReminderAttachmentStager {
    private struct Representation: Sendable {
        let fileExtension: String
        let typeIdentifier: String
        let signatureMatches: @Sendable (Data) -> Bool
    }

    private enum StagingError: Error, Equatable, Sendable {
        case invalidDirectory
        case invalidImage
    }

    private let directory: URL

    init(directory: URL) {
        self.directory = directory.standardizedFileURL
    }

    func stage(
        _ image: ImageBytes,
        productID: Product.ID
    ) async throws -> StagedReminderAttachment {
        guard productID > 0 else { throw ProductReminderError.invalidProductID }
        try Task.checkCancellation()
        let representation = try Self.representation(for: image)
        try prepareDirectory()
        try Task.checkCancellation()

        let fileURL = directory.appendingPathComponent(
            "product-\(productID)-\(UUID().uuidString).\(representation.fileExtension)",
            isDirectory: false
        ).standardizedFileURL
        guard fileURL.deletingLastPathComponent() == directory else {
            throw StagingError.invalidDirectory
        }

        do {
            try image.data.write(to: fileURL, options: .withoutOverwriting)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            try Task.checkCancellation()
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }

        let attachment = LocalNotificationAttachment(
            id: try LocalNotificationAttachmentID("store.product.thumbnail"),
            fileURL: fileURL,
            options: LocalNotificationAttachmentOptions(
                typeHint: representation.typeIdentifier
            )
        )
        return StagedReminderAttachment(attachment: attachment) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func prepareDirectory() throws {
        guard directory.isFileURL else { throw StagingError.invalidDirectory }
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            let values = try directory.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard isDirectory.boolValue,
                  values.isDirectory == true,
                  values.isSymbolicLink != true else {
                throw StagingError.invalidDirectory
            }
        } else {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
    }

    private nonisolated static func representation(
        for image: ImageBytes
    ) throws -> Representation {
        guard !image.data.isEmpty,
              image.pixelWidth > 0,
              image.pixelHeight > 0 else {
            throw StagingError.invalidImage
        }
        let representation: Representation
        switch image.mimeType.lowercased() {
        case "image/png":
            representation = Representation(
                fileExtension: "png",
                typeIdentifier: UTType.png.identifier,
                signatureMatches: { data in
                    [UInt8](data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
                }
            )
        case "image/jpeg":
            representation = Representation(
                fileExtension: "jpg",
                typeIdentifier: UTType.jpeg.identifier,
                signatureMatches: { [UInt8]($0.prefix(3)) == [0xFF, 0xD8, 0xFF] }
            )
        case "image/gif":
            representation = Representation(
                fileExtension: "gif",
                typeIdentifier: UTType.gif.identifier,
                signatureMatches: { data in
                    let prefix = [UInt8](data.prefix(6))
                    return prefix == Array("GIF87a".utf8)
                        || prefix == Array("GIF89a".utf8)
                }
            )
        case "image/webp":
            representation = Representation(
                fileExtension: "webp",
                typeIdentifier: UTType.webP.identifier,
                signatureMatches: { data in
                    let bytes = [UInt8](data.prefix(12))
                    guard bytes.count == 12 else { return false }
                    return Array(bytes[0..<4]) == Array("RIFF".utf8)
                        && Array(bytes[8..<12]) == Array("WEBP".utf8)
                }
            )
        default:
            throw StagingError.invalidImage
        }
        guard representation.signatureMatches(image.data) else {
            throw StagingError.invalidImage
        }
        return representation
    }
}
