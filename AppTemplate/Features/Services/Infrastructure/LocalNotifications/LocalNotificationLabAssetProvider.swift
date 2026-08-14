import AudioToolbox
import Foundation

nonisolated enum LocalNotificationLabAsset: CaseIterable, Sendable {
    case image
    case audio
    case video
}

nonisolated enum LocalNotificationLabAssetError: Error, Equatable, Sendable {
    case missing(String)
    case invalidFileURL(String)
    case unreadable(String)
    case invalidSoundDuration(String)
}

nonisolated enum LocalNotificationLabResource: Equatable, Hashable, Sendable {
    case attachment(LocalNotificationLabAsset)
    case sound
}

nonisolated enum LocalNotificationLabURLValidation: Equatable, Sendable {
    case valid
    case invalidFileURL
    case unreadable
    case soundTooLong
}

nonisolated
struct LocalNotificationLabAssetProvider: Sendable {
    private let resolve: @Sendable (LocalNotificationLabResource) -> URL?
    private let validate: @Sendable (URL) -> LocalNotificationLabURLValidation

    init(bundle: Bundle) {
        resolve = { resource in
            switch resource {
            case .attachment(.image):
                bundle.url(
                    forResource: "notification-demo-image",
                    withExtension: "png",
                    subdirectory: "NotificationDemo"
                ) ?? bundle.url(
                    forResource: "notification-demo-image",
                    withExtension: "png"
                )
            case .attachment(.audio), .sound:
                bundle.url(
                    forResource: "notification-demo",
                    withExtension: "aiff"
                )
            case .attachment(.video):
                bundle.url(
                    forResource: "notification-demo-video",
                    withExtension: "mov",
                    subdirectory: "NotificationDemo"
                ) ?? bundle.url(
                    forResource: "notification-demo-video",
                    withExtension: "mov"
                )
            }
        }
        validate = Self.validateFile
    }

    init(
        resolve: @escaping @Sendable (LocalNotificationLabResource) -> URL?,
        validate: @escaping @Sendable (URL) -> LocalNotificationLabURLValidation
    ) {
        self.resolve = resolve
        self.validate = validate
    }

    func attachmentURL(_ asset: LocalNotificationLabAsset) throws -> URL {
        try resolved(.attachment(asset), requiresSoundDuration: asset == .audio)
    }

    func notificationSoundName() throws -> String {
        try resolved(.sound, requiresSoundDuration: true).lastPathComponent
    }

    private func resolved(
        _ resource: LocalNotificationLabResource,
        requiresSoundDuration: Bool
    ) throws -> URL {
        let safeName = Self.safeName(for: resource)
        guard let url = resolve(resource) else {
            throw LocalNotificationLabAssetError.missing(safeName)
        }
        switch validate(url) {
        case .valid:
            return url
        case .invalidFileURL:
            throw LocalNotificationLabAssetError.invalidFileURL(safeName)
        case .unreadable:
            throw LocalNotificationLabAssetError.unreadable(safeName)
        case .soundTooLong:
            if requiresSoundDuration {
                throw LocalNotificationLabAssetError.invalidSoundDuration(safeName)
            }
            throw LocalNotificationLabAssetError.unreadable(safeName)
        }
    }

    private static func safeName(for resource: LocalNotificationLabResource) -> String {
        switch resource {
        case .attachment(.image): "notification-demo-image.png"
        case .attachment(.audio), .sound: "notification-demo.aiff"
        case .attachment(.video): "notification-demo-video.mov"
        }
    }

    private static func validateFile(_ url: URL) -> LocalNotificationLabURLValidation {
        guard url.isFileURL else { return .invalidFileURL }
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .isReadableKey
            ])
        } catch {
            return .unreadable
        }
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              values.isReadable == true,
              FileManager.default.isReadableFile(atPath: url.path) else {
            return .unreadable
        }
        guard url.pathExtension.lowercased() == "aiff" else { return .valid }
        return validSoundDuration(at: url) ? .valid : .soundTooLong
    }

    private static func validSoundDuration(at url: URL) -> Bool {
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr,
              let file else { return false }
        defer { AudioFileClose(file) }
        var duration = 0.0
        var size = UInt32(MemoryLayout.size(ofValue: duration))
        guard AudioFileGetProperty(
            file,
            kAudioFilePropertyEstimatedDuration,
            &size,
            &duration
        ) == noErr else { return false }
        return duration.isFinite && duration > 0 && duration < 30
    }
}
