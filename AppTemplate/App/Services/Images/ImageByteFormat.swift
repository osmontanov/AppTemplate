import Foundation

nonisolated
enum ImageByteFormat: String, CaseIterable, Sendable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case gif = "image/gif"
    case webp = "image/webp"

    var mimeType: String { rawValue }

    init?(contentType: String?) {
        guard let mediaType = contentType?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            let format = ImageByteFormat(rawValue: mediaType)
        else {
            return nil
        }
        self = format
    }

    init?(signatureOf data: Data) {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            self = .png
        } else if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            self = .jpeg
        } else if bytes.starts(with: Array("GIF87a".utf8))
            || bytes.starts(with: Array("GIF89a".utf8)) {
            self = .gif
        } else if bytes.count >= 12,
                  Array(bytes[0..<4]) == Array("RIFF".utf8),
                  Array(bytes[8..<12]) == Array("WEBP".utf8) {
            self = .webp
        } else {
            return nil
        }
    }
}
