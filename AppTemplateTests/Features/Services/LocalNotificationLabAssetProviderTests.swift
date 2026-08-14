import Foundation
import Testing
@testable import AppTemplate

struct LocalNotificationLabAssetProviderTests {
    @Test
    func injectedProviderResolvesEveryAttachmentAndTheNamedSound() throws {
        let root = URL(fileURLWithPath: "/fixture", isDirectory: true)
        let expected: [LocalNotificationLabResource: URL] = [
            .attachment(.image): root.appendingPathComponent("NotificationDemo/notification-demo-image.png"),
            .attachment(.audio): root.appendingPathComponent("notification-demo.aiff"),
            .attachment(.video): root.appendingPathComponent("NotificationDemo/notification-demo-video.mov"),
            .sound: root.appendingPathComponent("notification-demo.aiff")
        ]
        let provider = LocalNotificationLabAssetProvider(
            resolve: { expected[$0] },
            validate: { _ in .valid }
        )

        #expect(try provider.attachmentURL(.image) == expected[.attachment(.image)])
        #expect(try provider.attachmentURL(.audio) == expected[.attachment(.audio)])
        #expect(try provider.attachmentURL(.video) == expected[.attachment(.video)])
        #expect(try provider.notificationSoundName() == "notification-demo.aiff")
    }

    @Test
    func everyResourceMapsMissingInvalidAndUnreadableToSafeTypedErrors() throws {
        for resource in resourceTable {
            let missing = LocalNotificationLabAssetProvider(
                resolve: { candidate in candidate == resource.resource ? nil : resource.url },
                validate: { _ in .valid }
            )
            #expect(throws: LocalNotificationLabAssetError.missing(resource.safeName)) {
                try resolve(resource, from: missing)
            }

            for (validation, expectedError) in [
                (LocalNotificationLabURLValidation.invalidFileURL,
                 LocalNotificationLabAssetError.invalidFileURL(resource.safeName)),
                (.unreadable, .unreadable(resource.safeName))
            ] {
                let provider = LocalNotificationLabAssetProvider(
                    resolve: { _ in resource.url },
                    validate: { _ in validation }
                )
                #expect(throws: expectedError) {
                    try resolve(resource, from: provider)
                }
            }
        }
    }

    @Test
    func deterministicThirtySecondSoundIsRejectedOnlyWithTheLeafSoundName() {
        let provider = LocalNotificationLabAssetProvider(
            bundle: Bundle(for: LocalNotificationLabAssetProviderTestBundleMarker.self)
        )

        #expect(throws: LocalNotificationLabAssetError.invalidSoundDuration("notification-demo.aiff")) {
            try provider.notificationSoundName()
        }
    }

    @Test
    func bundledDemoAssetsAndNamedSoundResolve() throws {
        let provider = LocalNotificationLabAssetProvider(bundle: .main)
        for asset in LocalNotificationLabAsset.allCases {
            let url = try provider.attachmentURL(asset)
            #expect(url.isFileURL)
            #expect(FileManager.default.isReadableFile(atPath: url.path))
            #expect((try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true)
        }
        #expect(try provider.notificationSoundName() == "notification-demo.aiff")
    }

    private struct ResourceCase {
        let resource: LocalNotificationLabResource
        let url: URL
        let safeName: String
    }

    private var resourceTable: [ResourceCase] {
        [
            ResourceCase(resource: .attachment(.image), url: URL(fileURLWithPath: "/fixture/image.png"), safeName: "notification-demo-image.png"),
            ResourceCase(resource: .attachment(.audio), url: URL(fileURLWithPath: "/fixture/audio.aiff"), safeName: "notification-demo.aiff"),
            ResourceCase(resource: .attachment(.video), url: URL(fileURLWithPath: "/fixture/video.mov"), safeName: "notification-demo-video.mov"),
            ResourceCase(resource: .sound, url: URL(fileURLWithPath: "/fixture/sound.aiff"), safeName: "notification-demo.aiff")
        ]
    }

    private func resolve(
        _ resource: ResourceCase,
        from provider: LocalNotificationLabAssetProvider
    ) throws -> Any {
        switch resource.resource {
        case let .attachment(asset): try provider.attachmentURL(asset)
        case .sound: try provider.notificationSoundName()
        }
    }
}

private final class LocalNotificationLabAssetProviderTestBundleMarker: NSObject {}
