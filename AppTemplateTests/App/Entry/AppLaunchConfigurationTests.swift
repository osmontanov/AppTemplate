import Foundation
import Testing
@testable import AppTemplate

struct AppLaunchConfigurationTests {
    @Test(arguments: UITestScenario.Name.allCases)
    func parsesEveryStableScenarioName(_ name: UITestScenario.Name) throws {
        let scenario = try UITestScenario.named(name.rawValue).preparedForLaunch()
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "--ui-testing", "--ui-test-scenario", name.rawValue
        ]) == .uiTesting(scenario))
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "--ui-test-scenario", name.rawValue, "--ui-testing"
        ]) == .uiTesting(scenario))
    }

    @Test
    func unrelatedProcessArgumentsAreIgnored() throws {
        let scenario = try UITestScenario.named("guest-store").preparedForLaunch()
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "-NSDocumentRevisionsDebugMode", "YES",
            "--ui-testing", "--ui-test-scenario", "guest-store"
        ]) == .uiTesting(scenario))
        #expect(AppLaunchConfiguration(arguments: ["AppTemplate", "-SomeFlag"]) == .live)
    }

    #if os(macOS)
    @Test
    func supportsOneLeadingPersistenceIsolationPair() throws {
        let scenario = try UITestScenario.named("services-basic")
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-scenario", "services-basic"
        ]) == .uiTesting(scenario))
    }

    @Test(arguments: [
        ["AppTemplate", "-ApplePersistenceIgnoreState", "NO", "--ui-testing", "--ui-test-scenario", "services-basic"],
        ["AppTemplate", "--ui-testing", "--ui-test-scenario", "services-basic", "-ApplePersistenceIgnoreState", "YES"],
        ["AppTemplate", "-ApplePersistenceIgnoreState", "YES", "-ApplePersistenceIgnoreState", "YES", "--ui-testing", "--ui-test-scenario", "services-basic"]
    ])
    func malformedPersistenceIsolationNeverProducesValidUITesting(_ arguments: [String]) {
        guard case .invalidUITesting = AppLaunchConfiguration(arguments: arguments) else {
            Issue.record("Malformed persistence isolation produced a valid launch")
            return
        }
    }
    #endif

    @Test(arguments: [
        (["AppTemplate", "--ui-testing"], UITestConfigurationError.missingScenario),
        (["AppTemplate", "--ui-test-scenario", "guest-store"], .missingScenario),
        (["AppTemplate", "--ui-testing", "--ui-testing", "--ui-test-scenario", "guest-store"], .duplicateOption("--ui-testing")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "guest-store", "--ui-test-scenario", "services-basic"], .duplicateOption("--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-root", "main"], .unknownOption("--ui-test-root")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "guest-store", "--ui-surprise"], .unknownOption("--ui-surprise")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario"], .malformedValue(option: "--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", ""], .malformedValue(option: "--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "--other"], .malformedValue(option: "--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "not-catalogued"], .unknownScenario("not-catalogued"))
    ])
    func uiTestIntentNeverFallsBackToLive(
        _ arguments: [String],
        _ error: UITestConfigurationError
    ) {
        #expect(AppLaunchConfiguration(arguments: arguments) == .invalidUITesting(error))
    }

    @Test
    func testLaunchesAlwaysUseEphemeralNavigationPersistence() throws {
        #expect(AppLaunchConfiguration.live.sceneNavigationPersistencePolicy == .restored)
        #expect(AppLaunchConfiguration.uiTesting(try .named("guest-store")).sceneNavigationPersistencePolicy == .ephemeral)
        #expect(AppLaunchConfiguration.invalidUITesting(.missingScenario).sceneNavigationPersistencePolicy == .ephemeral)
    }

    @MainActor
    @Test
    func guestStoreLaunchProvidesTypedOfflineSeeds() async throws {
        let scenario = try guestStoreLaunchScenario()

        #expect(scenario.networkPolicy == .failClosed)
        #expect(scenario.sessionSeed.keychainData == nil)
        #expect(scenario.sessionSeed.validationMode == .disabled)
        #expect(scenario.localDatabaseSeed.examples == [
            ExampleRecord(id: "guest-store-example", payload: "offline")
        ])
        #expect(scenario.localDatabaseSeed.favorites.count == 1)
        #expect(
            scenario.localDatabaseSeed.cart
                == CartAggregate(
                    id: CartAggregate.singletonID,
                    revision: 0,
                    lines: []
                )
        )
        #expect(!scenario.preferencesSeed.encodedValues.isEmpty)
        #expect(!scenario.remoteSteps.isEmpty)
        #expect(!scenario.imageSeed.steps.isEmpty)

        let dependencies = AppDependencies.uiTesting(scenario: scenario)
        try await dependencies.bootstrap()

        #expect(
            try await dependencies.localDatabase.fetch(
                ExampleRecord.self,
                id: "guest-store-example"
            ) == ExampleRecord(id: "guest-store-example", payload: "offline")
        )
        #expect(
            try await dependencies.favorites.favorites(userID: 1)
                == scenario.localDatabaseSeed.favorites
        )
        #expect(
            try await dependencies.cart.cart()
                == scenario.localDatabaseSeed.cart
        )
        #expect(
            await dependencies.storePreferences.current()
                == StorePreferences(
                    layout: .list,
                    sort: .featured,
                    preferredRemotePageSize: 10
                )
        )
    }

    @MainActor
    @Test
    func guestStoreOrderedScriptsReachExhaustedThroughRealServices()
        async throws {
        let scenario = try guestStoreLaunchScenario()
        let dependencies = AppDependencies.uiTesting(scenario: scenario)
        try await dependencies.bootstrap()

        func consumeDetail(_ id: Product.ID) async throws {
            #expect(try await dependencies.remote.product(id: id).id == id)
            #expect(
                try await dependencies.remote.products(ProductPageRequest(
                    mode: .category("phones"),
                    sort: nil,
                    limit: 26,
                    skip: 0
                )).products.map(\.id) == [1, 2]
            )
        }

        func consumeCatalogReentry() async throws {
            for _ in 0..<2 {
                #expect(
                    try await dependencies.remote.products(ProductPageRequest(
                        mode: .all,
                        sort: nil,
                        limit: 10,
                        skip: 0
                    )).products.map(\.id) == [1, 2]
                )
            }
        }

        #expect(try await dependencies.remote.categories().map(\.slug) == ["phones"])
        #expect(
            try await dependencies.remote.products(ProductPageRequest(
                mode: .all,
                sort: nil,
                limit: 10,
                skip: 0
            )).products.map(\.id) == [1, 2]
        )
        #expect(
            try await dependencies.remote.products(ProductPageRequest(
                mode: .all,
                sort: nil,
                limit: 10,
                skip: 2
            )).products.map(\.id) == [3]
        )
        try await consumeDetail(1)
        #expect(try await dependencies.remote.product(id: 1).reviews.count == 1)
        try await consumeDetail(1)
        try await consumeDetail(2)
        try await consumeDetail(1)
        try await consumeCatalogReentry()
        try await consumeCatalogReentry()

        for step in scenario.imageSeed.steps {
            _ = try await dependencies.imageLoader.load(step.url, policy: .product)
        }

        let tracker = try #require(dependencies.uiTestScriptTracker)
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .exhausted)
    }

    @MainActor
    @Test
    func guestStoreCheckoutConflictsOnceThenSucceeds() async throws {
        let dependencies = AppDependencies.uiTesting(
            scenario: try guestStoreLaunchScenario()
        )
        try await dependencies.bootstrap()
        let product = ProductSnapshot(
            id: 2,
            title: "Offline Phone Two",
            price: Decimal(79),
            thumbnailURL: nil
        )
        let added = try await dependencies.cart.add(product, quantity: 1)

        await #expect(throws: CartRepositoryError.revisionConflict(
            expected: added.revision,
            actual: added.revision + 1
        )) {
            try await dependencies.cart.checkout(expectedRevision: added.revision)
        }

        let refreshed = try await dependencies.cart.cart()
        #expect(refreshed.revision == added.revision + 1)
        #expect(refreshed.lines.first?.quantity == 2)
        try await dependencies.cart.checkout(expectedRevision: refreshed.revision)
        #expect(try await dependencies.cart.cart().lines.isEmpty)
    }

    private func guestStoreLaunchScenario() throws -> UITestScenario {
        let configuration = AppLaunchConfiguration(arguments: [
            "AppTemplate", "--ui-testing", "--ui-test-scenario", "guest-store"
        ])
        guard case let .uiTesting(scenario) = configuration else {
            Issue.record("Guest Store did not produce a UI-test scenario")
            throw UITestConfigurationError.missingScenario
        }
        return scenario
    }
}
