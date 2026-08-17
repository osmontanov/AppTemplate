import Foundation
import Testing
@testable import AppTemplate

struct AppTextLocalizationTests {
    @Test
    func arabicStoreTitleIsTranslatedAndResolvesFromDedicatedTable() throws {
        let catalog = try AppTextCatalogFixture.loadSourceCatalog()
        let arabic = try #require(
            catalog.strings["Store"]?.localizations?["ar"]?.stringUnit.value
        )

        #expect(arabic == "المتجر")
        #expect(arabic != catalog.englishValue(for: "Store"))
        var resource = AppText.resource("Store")
        resource.locale = Locale(identifier: "ar_SA")
        #expect(String(localized: resource) == arabic)
    }

    // A symbolic key only exists because interpolation would make different
    // strings collide on one format key. Such a key resolves to visible copy
    // solely because every call site supplies `defaultValue:` — without it an
    // untranslated locale would render the raw key.
    @Test
    func symbolicKeysAlwaysCarryTheirVisibleCopyAtTheCallSite() throws {
        let fixture = AppTextCatalogFixture()
        let catalog = try fixture.loadSourceCatalog()
        let symbolicKeys = Set(catalog.strings.keys.filter { key in
            catalog.englishValue(for: key).map { $0 != key } ?? false
        })

        #expect(!symbolicKeys.isEmpty)
        for key in symbolicKeys {
            #expect(catalog.englishValue(for: key)?.isEmpty == false)
        }

        var usedSymbolicKeys: Set<String> = []
        for relativePath in Self.producerManifest {
            let source = try fixture.source(at: relativePath)
            for key in fixture.catalogKeys(in: source) where symbolicKeys.contains(key) {
                usedSymbolicKeys.insert(key)
                let pattern = #"AppText\.(?:resource|string)\(\s*\""#
                    + NSRegularExpression.escapedPattern(for: key)
                    + #"\"\s*,\s*\n?\s*defaultValue:"#
                #expect(
                    source.range(of: pattern, options: .regularExpression) != nil,
                    "\(relativePath) uses symbolic key \(key) without a defaultValue"
                )
            }
        }
        #expect(usedSymbolicKeys == symbolicKeys)
    }

    @Test
    func producerManifestIsSortedCompleteAndCatalogBacked() throws {
        let fixture = AppTextCatalogFixture()
        let catalog = try fixture.loadSourceCatalog()

        #expect(Self.producerManifest == Self.producerManifest.sorted())
        let expectedProducers = Set(Self.producerManifest)
        let discoveredProducers = try fixture.discoveredVisibleProducers(
            required: expectedProducers
        )
        #expect(
            discoveredProducers == expectedProducers,
            "Unexpected producers: \(discoveredProducers.subtracting(expectedProducers).sorted()); missing producers: \(expectedProducers.subtracting(discoveredProducers).sorted())"
        )

        for relativePath in Self.producerManifest {
            let source = try fixture.source(at: relativePath)
            for forbidden in Self.rawVisibleLiteralPatterns {
                #expect(
                    source.range(of: forbidden, options: .regularExpression) == nil,
                    "\(relativePath) still contains visible copy matching \(forbidden)"
                )
            }

            for key in fixture.catalogKeys(in: source) {
                #expect(catalog.strings[key] != nil, "Missing AppText catalog key \(key) used by \(relativePath)")
                #expect(catalog.englishValue(for: key)?.isEmpty == false)
            }
        }
    }

    private static let rawVisibleLiteralPatterns = [
        #"\b(?:Text|Button|Label|Section|GroupBox|Toggle|Picker|Menu|ProgressView|ContentUnavailableView|LabeledContent)\s*\(\s*\""#,
        #"\.(?:navigationTitle|accessibilityLabel|accessibilityHint|alert|confirmationDialog)\s*\(\s*\""#,
        #"(?:actualResult|errorMessage|message)\s*=\s*(?:\.\w+\s*\()?\s*\""#,
        #"\.(?:success|failure)\s*\(\s*\""#,
        #"\b(?:title|subtitle|body|actionTitle|categoryTitle)\s*:\s*\""#
    ]

    private static let producerManifest = [
        "AppTemplate/App/Navigation/Containers/AppSceneView.swift",
        "AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift",
        "AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift",
        "AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift",
        "AppTemplate/App/Navigation/Containers/SessionRestoringView.swift",
        "AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift",
        "AppTemplate/Features/Authentication/Screens/Authentication/State/AuthenticationState.swift",
        "AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift",
        "AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift",
        "AppTemplate/Features/Authentication/Screens/AuthenticationHelp/View/AuthenticationHelpView.swift",
        "AppTemplate/Features/Maintenance/Flow/MaintenanceFlowView.swift",
        "AppTemplate/Features/Maintenance/Screens/Maintenance/View/MaintenanceView.swift",
        "AppTemplate/Features/Onboarding/Flow/OnboardingFlowView.swift",
        "AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift",
        "AppTemplate/Features/Services/Flow/ServicesFlowView.swift",
        "AppTemplate/Features/Services/Infrastructure/AppState/ServicesAppStateStatus.swift",
        "AppTemplate/Features/Services/Navigation/ServicesRoute.swift",
        "AppTemplate/Features/Services/Screens/AppInfo/ServicesAppInfoView.swift",
        "AppTemplate/Features/Services/Screens/AppState/ServicesAppStateView.swift",
        "AppTemplate/Features/Services/Screens/AppState/ServicesAppStateViewModel.swift",
        "AppTemplate/Features/Services/Screens/Keychain/KeychainLab.swift",
        "AppTemplate/Features/Services/Screens/Keychain/KeychainLabView.swift",
        "AppTemplate/Features/Services/Screens/Keychain/KeychainLabViewModel.swift",
        "AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabState.swift",
        "AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabView.swift",
        "AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabViewModel.swift",
        "AppTemplate/Features/Services/Screens/LocalNotifications/LocalNotificationLabView.swift",
        "AppTemplate/Features/Services/Screens/LocalNotifications/LocalNotificationLabViewModel.swift",
        "AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabView.swift",
        "AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabViewModel.swift",
        "AppTemplate/Features/Services/Screens/ServicesCatalog/View/ServicesCatalogView.swift",
        "AppTemplate/Features/Services/Screens/ServicesCatalog/ViewModel/ServicesCatalogViewModel.swift",
        "AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLab.swift",
        "AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLabView.swift",
        "AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLabViewModel.swift",
        "AppTemplate/Features/Services/Shared/Model/ServiceLabGuide.swift",
        "AppTemplate/Features/Services/Shared/View/ServiceLabGuideView.swift",
        "AppTemplate/Features/Store/Checkout/Flow/CheckoutFlowView.swift",
        "AppTemplate/Features/Store/Flow/StoreFlowView.swift",
        "AppTemplate/Features/Store/Reminders/ProductReminderRepository.swift",
        "AppTemplate/Features/Store/Reminders/StoreProductNotificationCategory.swift",
        "AppTemplate/Features/Store/Screens/Cart/View/CartView.swift",
        "AppTemplate/Features/Store/Screens/Cart/ViewModel/CartViewModel.swift",
        "AppTemplate/Features/Store/Screens/Catalog/View/CatalogView.swift",
        "AppTemplate/Features/Store/Screens/Catalog/ViewModel/CatalogViewModel.swift",
        "AppTemplate/Features/Store/Screens/Favorites/View/FavoritesView.swift",
        "AppTemplate/Features/Store/Screens/Preferences/View/StorePreferencesForm.swift",
        "AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift",
        "AppTemplate/Features/Store/Screens/ProductDetail/ViewModel/ProductDetailViewModel.swift",
        "AppTemplate/Features/Store/Screens/ProductReminder/View/ProductReminderView.swift",
        "AppTemplate/Features/Store/Screens/ProductReminder/ViewModel/ProductReminderViewModel.swift",
        "AppTemplate/Features/Store/Screens/Profile/View/ProfileView.swift",
        "AppTemplate/Features/Store/Screens/Profile/ViewModel/ProfileViewModel.swift",
        "AppTemplate/Features/Store/Screens/Reviews/View/ReviewsView.swift",
        "AppTemplate/Features/Store/Screens/Reviews/ViewModel/ReviewsViewModel.swift",
        "AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryView.swift",
        "AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryViewModel.swift",
        "AppTemplate/Features/Store/Settings/StoreSettingsSceneView.swift"
    ]
}

private struct AppTextCatalogFixture {
    struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct StringUnit: Decodable {
                    let value: String
                }

                let stringUnit: StringUnit
            }

            let localizations: [String: Localization]?
        }

        let strings: [String: Entry]

        func englishValue(for key: String) -> String? {
            strings[key]?.localizations?["en"]?.stringUnit.value
        }
    }

    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .resolvingSymlinksInPath()

    static func loadSourceCatalog() throws -> Catalog {
        try AppTextCatalogFixture().loadSourceCatalog()
    }

    func loadSourceCatalog() throws -> Catalog {
        let url = Self.repositoryRoot
            .appendingPathComponent("AppTemplate/Resources/AppText.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    func source(at relativePath: String) throws -> String {
        try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    func catalogKeys(in source: String) -> Set<String> {
        let pattern = #"AppText\.(?:resource|string)\(\s*\"([^\"]+)\""#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..., in: source)
        return Set(expression.matches(in: source, range: range).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: source) else { return nil }
            let key = String(source[keyRange])
            return key.contains("\\(") ? nil : key
        })
    }

    func discoveredVisibleProducers(required: Set<String>) throws -> Set<String> {
        let roots = [
            "AppTemplate/Features/Store",
            "AppTemplate/Features/Services",
            "AppTemplate/Features/Authentication",
            "AppTemplate/Features/Onboarding",
            "AppTemplate/Features/Maintenance",
            "AppTemplate/App/Navigation/Containers"
        ]
        let explicit = Set([
            "AppTemplate/App/Navigation/Containers/AppSceneView.swift",
            "AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift",
            "AppTemplate/App/Navigation/Containers/SessionRestoringView.swift",
            "AppTemplate/Features/Services/Navigation/ServicesRoute.swift",
            "AppTemplate/Features/Services/Shared/Model/ServiceLabGuide.swift",
            "AppTemplate/Features/Store/Reminders/ProductReminderRepository.swift",
            "AppTemplate/Features/Store/Reminders/StoreProductNotificationCategory.swift",
            "AppTemplate/Features/Store/Screens/Preferences/View/StorePreferencesForm.swift"
        ])
        let manager = FileManager.default
        var result = required.union(explicit)

        for root in roots {
            let rootURL = Self.repositoryRoot.appendingPathComponent(root)
            guard let enumerator = manager.enumerator(at: rootURL, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let repositoryPath = normalizedFileSystemPath(Self.repositoryRoot)
                let sourcePath = normalizedFileSystemPath(url)
                let repositoryPrefix = repositoryPath + "/"
                guard sourcePath.hasPrefix(repositoryPrefix) else { continue }
                let relative = String(sourcePath.dropFirst(repositoryPrefix.count))
                let source = try String(contentsOf: url, encoding: .utf8)
                let alwaysVisible = !relative.hasPrefix("AppTemplate/App/Navigation/Containers/")
                    && (url.lastPathComponent.hasSuffix("View.swift")
                        || url.lastPathComponent.hasSuffix("FlowView.swift"))
                let authoredProducer = source.contains("AppText.")
                    || source.range(
                        of: #"\b(?:Text|Button|Label|Section|GroupBox|Toggle|Picker|Menu|ProgressView|ContentUnavailableView|LabeledContent)\s*\(\s*\""#,
                        options: .regularExpression
                    ) != nil
                    || source.contains("LocalNotificationContent(")
                    || source.contains("ServiceLabResult") && source.contains("\"")
                if alwaysVisible || authoredProducer {
                    result.insert(relative)
                }
            }
        }

        return result
    }

    private func normalizedFileSystemPath(_ url: URL) -> String {
        let standardizedPath = url.standardizedFileURL.path
        if standardizedPath.hasPrefix("/private/var/") {
            return String(standardizedPath.dropFirst("/private".count))
        }
        return standardizedPath
    }
}
