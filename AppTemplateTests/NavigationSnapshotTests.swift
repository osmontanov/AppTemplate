import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct NavigationSnapshotTests {
    @Test
    func snapshotRoundTripsThroughJSON() throws {
        let router = AppRouter(selectedSection: .browse)
        router.home.push(.details)
        router.browse.push(.item(id: "swiftui"))
        router.settings.push(.about)

        let data = try NavigationSnapshotCodec.encode(router.snapshot)
        let decoded = try NavigationSnapshotCodec.decode(data)

        #expect(decoded == router.snapshot)
    }

    @Test
    func restorePrunesUnavailableBrowseRecords() throws {
        let snapshot = NavigationSnapshot(
            selectedSection: .browse,
            homePath: [.details],
            browsePath: [.item(id: "swiftui"), .item(id: "deleted")],
            settingsPath: [.about]
        )
        let router = AppRouter()
        let data = try NavigationSnapshotCodec.encode(snapshot)

        #expect(router.restore(from: data) == .restored)
        #expect(router.browse.path == [.item(id: "swiftui")])
    }

    @Test
    func corruptDataResetsNavigation() {
        let router = AppRouter(selectedSection: .settings)
        router.settings.push(.about)

        #expect(router.restore(from: Data("not-json".utf8)) == .reset(.corruptData))
        #expect(router.selectedSection == .home)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func futureSchemaResetsNavigation() throws {
        let snapshot = NavigationSnapshot(
            schemaVersion: 999,
            selectedSection: .settings,
            homePath: [],
            browsePath: [],
            settingsPath: [.about]
        )
        let router = AppRouter()

        #expect(
            router.restore(from: try NavigationSnapshotCodec.encode(snapshot))
                == .reset(.unsupportedSchema(999))
        )
    }

    @Test
    func transientAndAuthenticationStateIsNotRestored() throws {
        let source = AppRouter(flow: .authentication)
        source.home.sheet = .navigationGuide
        source.home.alert = .resetNavigation
        _ = source.handle(.selectSection(.settings))

        let restored = AppRouter()
        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        #expect(restored.restore(from: data) == .restored)

        #expect(restored.flow == .main)
        #expect(restored.home.sheet == nil)
        #expect(restored.home.alert == nil)
        #expect(restored.pendingIntent == nil)
    }
}
