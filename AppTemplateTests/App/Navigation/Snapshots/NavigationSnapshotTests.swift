import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct NavigationSnapshotTests {
    @Test
    func routeWireTagsAndPositiveIdentifiersAreStrict() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        #expect(String(decoding: try encoder.encode(StoreRoute.product(42)), as: UTF8.self) == #"{"productID":42,"tag":"product"}"#)
        #expect(String(decoding: try encoder.encode(StoreRoute.reviews(7)), as: UTF8.self) == #"{"productID":7,"tag":"reviews"}"#)
        #expect(String(decoding: try encoder.encode(StoreRoute.cart), as: UTF8.self) == #"{"tag":"cart"}"#)
        #expect(String(decoding: try encoder.encode(ServicesRoute.localNotifications), as: UTF8.self) == #"{"tag":"local-notifications"}"#)
        #expect(throws: DecodingError.self) { try decodeStore(#"{"tag":"cart","productID":1}"#) }
        #expect(throws: DecodingError.self) { try decodeServices(#"{"tag":"app-info","extra":true}"#) }
        #expect(throws: DecodingError.self) { try decodeStore(#"{"tag":"product","productID":0}"#) }
        #expect(throws: DecodingError.self) { try decodeStore(#"{"tag":"reviews","productID":-1}"#) }
    }

    @Test
    func schemaFiveRoundTripsTypedPathsAndCheckpoint() throws {
        let checkpoint = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let source = makeRouter(selectedSection: .services)
        source.store.push(.product(42))
        source.store.push(.cart)
        source.services.open(.appInfo)
        let data = try NavigationSnapshotCodec.encode(source.makeSnapshot(lastAppliedTransitionID: checkpoint))
        let restored = makeRouter()

        let restoration = restored.restore(from: data)

        #expect(restoration == NavigationRestoration(result: .restored, lastAppliedTransitionID: checkpoint))
        #expect(restored.selectedSection == .services)
        #expect(restored.store.path == [.product(42), .cart])
        #expect(restored.services.path == [.appInfo])
        #expect(restored.snapshot.schemaVersion == 5)
    }

    @Test
    func schemaFiveOmitsEveryProtectedTransientValue() throws {
        let source = makeRouter(selectedSection: .services)
        source.store.path = [.profile, .favorites, .product(7)]
        _ = source.store.reconcile(authenticated(userID: 1, revision: 7))
        _ = source.store.selectProfileSection(
            .account,
            session: authenticated(userID: 1, revision: 7).state
        )
        source.store.cacheAccountPresentation(
            ProfileAccountPresentation(
                userID: 1,
                displayName: "User 1",
                availability: .offline(.transport)
            )
        )
        _ = source.store.requestProtected(.favorite(9), session: .guest)

        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let restored = makeRouter()
        _ = restored.restore(from: data)

        #expect(
            Set(object.keys) == Set([
                "schemaVersion",
                "selectedSection",
                "storePath",
                "servicesPath"
            ])
        )
        #expect(object["schemaVersion"] as? Int == 5)
        #expect(restored.store.path == [.profile, .favorites, .product(7)])
        #expect(restored.store.presentation == nil)
        #expect(restored.store.pendingProtectedAction == nil)
        #expect(restored.store.profileSection == .overview)
        #expect(restored.store.cachedAccountPresentation == nil)
        #expect(restored.store.lastAppliedSessionRevision == nil)
    }

    @Test(arguments: [2, 3])
    func schemasTwoAndThreeDiscardLegacyPaths(schemaVersion: Int) throws {
        let data = Data(#"{"schemaVersion":\#(schemaVersion),"selectedSection":"settings","homePath":{"data":null},"browsePath":{"data":null},"projectsPath":{"data":null},"settingsPath":{"data":null}}"#.utf8)
        let router = makeRouter(selectedSection: .services)
        router.store.push(.cart)
        router.services.open(.keychain)

        let result = router.restore(from: data)

        #expect(result.result == .migrated(from: schemaVersion))
        #expect(result.lastAppliedTransitionID == nil)
        #expect(router.selectedSection == .store)
        #expect(router.store.path.isEmpty)
        #expect(router.services.path.isEmpty)
    }

    @Test
    func schemaFourPreservesOnlyTransitionCheckpoint() throws {
        let checkpoint = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let data = Data(#"{"schemaVersion":4,"lastAppliedTransitionID":"\#(checkpoint)","selectedSection":"projects","homePath":{"data":null},"browsePath":{"data":null},"projectsPath":{"data":null},"settingsPath":{"data":null}}"#.utf8)
        let router = makeRouter(selectedSection: .services)

        let result = router.restore(from: data)

        #expect(result.result == .migrated(from: 4))
        #expect(result.lastAppliedTransitionID?.uuidString == checkpoint)
        #expect(router.snapshot == NavigationSnapshot(selectedSection: .store, storePath: [], servicesPath: []))
    }

    @Test
    func invalidStoreRouteRecoversOnlyStore() throws {
        let data = Data(#"{"schemaVersion":5,"selectedSection":"services","storePath":[{"tag":"product","productID":0}],"servicesPath":[{"tag":"keychain"}]}"#.utf8)
        let router = makeRouter()

        #expect(router.restore(from: data).result == .recovered([.store]))
        #expect(router.store.path.isEmpty)
        #expect(router.services.path == [.keychain])
        #expect(router.selectedSection == .services)
    }

    @Test
    func invalidServicesRouteRecoversOnlyServices() throws {
        let data = Data(#"{"schemaVersion":5,"selectedSection":"store","storePath":[{"tag":"profile"}],"servicesPath":[{"tag":"app-info","extra":true}]}"#.utf8)
        let router = makeRouter()

        #expect(router.restore(from: data).result == .recovered([.services]))
        #expect(router.store.path == [.profile])
        #expect(router.services.path.isEmpty)
    }

    @Test
    func unknownTopLevelSchemaFiveKeyResetsEverything() {
        let data = Data(#"{"schemaVersion":5,"selectedSection":"store","storePath":[],"servicesPath":[],"extra":true}"#.utf8)
        let router = makeRouter(selectedSection: .services)
        router.store.push(.cart)
        router.services.open(.remoteAPI)

        #expect(router.restore(from: data).result == .reset(.corruptData))
        #expect(router.selectedSection == .store)
        #expect(router.store.path.isEmpty)
        #expect(router.services.path.isEmpty)
    }

    @Test
    func futureSchemaResetsMemoryAndRemainsStorageAuthority() throws {
        let future = Data(#"{"schemaVersion":99,"future":"keep"}"#.utf8)
        let router = makeRouter(selectedSection: .services)
        router.store.push(.cart)

        #expect(router.restore(from: future).result == .preservedFutureSchema(99))
        #expect(router.selectedSection == .store)
        #expect(router.store.path.isEmpty)
        #expect(try NavigationSnapshotCodec.encodingIfChanged(router.snapshot, comparedTo: future) == nil)
    }

    @Test
    func unchangedSchemaFiveSnapshotDoesNotRequestEncoding() throws {
        let router = makeRouter()
        router.store.push(.favorites)
        let data = try NavigationSnapshotCodec.encode(router.snapshot)
        #expect(try NavigationSnapshotCodec.encodingIfChanged(router.snapshot, comparedTo: data) == nil)
    }

    private func makeRouter(selectedSection: AppSection = .store) -> AppRouter {
        AppRouter(appFlowRouter: AppFlowRouter(flow: .main), selectedSection: selectedSection)
    }

    private func authenticated(
        userID: Int,
        revision: UInt64
    ) -> SessionPresentation {
        SessionPresentation(
            state: .authenticated(
                UserProfile(
                    id: userID,
                    username: "user\(userID)",
                    firstName: "User",
                    lastName: "\(userID)",
                    imageURL: nil
                ),
                availability: .online
            ),
            revision: revision
        )
    }
}

private func decodeStore(_ value: String) throws -> StoreRoute {
    try JSONDecoder().decode(StoreRoute.self, from: Data(value.utf8))
}

private func decodeServices(_ value: String) throws -> ServicesRoute {
    try JSONDecoder().decode(ServicesRoute.self, from: Data(value.utf8))
}
