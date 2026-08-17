import SwiftUI
import Testing
@testable import AppTemplate

struct AccessibilityUITestScenarioTests {
    @Test
    func accessibilityScenarioIsOfflineAndStartsAtOnboarding() throws {
        let scenario = try UITestScenario.named("accessibility-smoke")
        #expect(scenario.id == .accessibilitySmoke)
        #expect(scenario.appState == .initial)
    }

    @Test
    func presentationOverridePresetsFreezeTheDocumentedWire() {
        #expect(UITestPresentationOverrides.standard == .init(
            contentSize: .standard,
            layoutDirection: .leftToRight,
            locale: .system,
            reduceMotion: false
        ))
        #expect(UITestPresentationOverrides.largestText == .init(
            contentSize: .accessibilityExtraExtraExtraLarge,
            layoutDirection: .leftToRight,
            locale: .system,
            reduceMotion: false
        ))
        #expect(UITestPresentationOverrides.arabicRTL == .init(
            contentSize: .standard,
            layoutDirection: .rightToLeft,
            locale: .arabic,
            reduceMotion: false
        ))
        #expect(UITestContentSize.accessibilityExtraExtraExtraLarge.dynamicTypeSize == .accessibility5)
        #expect(UITestLayoutDirection.rightToLeft.swiftUILayoutDirection == .rightToLeft)
        #expect(UITestLocale.arabic.localeIdentifier == "ar_SA")
        #expect(UITestLocale.system.localeIdentifier == nil)
    }

    @Test
    func validUITestDeepLinkHarnessFreezesExactParserInputs() {
        #expect(UITestDeepLinkHarnessAction.product.accessibilityIdentifier ==
            "ui-test.action.open-product-link")
        #expect(UITestDeepLinkHarnessAction.product.url.absoluteString ==
            "apptemplate://store/product/1")
        #expect(UITestDeepLinkHarnessAction.favorites.accessibilityIdentifier ==
            "ui-test.action.open-favorites-link")
        #expect(UITestDeepLinkHarnessAction.favorites.url.absoluteString ==
            "apptemplate://store/favorites")
        #expect(UITestScenario.Name.guestStore.deepLinkHarnessAction == .product)
        #expect(UITestScenario.Name.protectedFavorite.deepLinkHarnessAction == .favorites)
        #expect(UITestScenario.Name.productReminder.deepLinkHarnessAction == nil)
        #expect(UITestScenario.Name.servicesBasic.deepLinkHarnessAction == nil)
        #expect(UITestScenario.Name.accessibilitySmoke.deepLinkHarnessAction == nil)
    }

    @Test
    func presentationOverridesParseOnlyInsideValidUITestLaunch() throws {
        let configuration = AppLaunchConfiguration(arguments: [
            "AppTemplate", "--ui-testing", "--ui-test-scenario", "accessibility-smoke",
            "--ui-test-content-size", "accessibilityExtraExtraExtraLarge",
            "--ui-test-layout-direction", "rightToLeft", "--ui-test-locale", "ar_SA",
            "--ui-test-reduce-motion"
        ])
        guard case let .uiTesting(scenario, overrides) = configuration else {
            Issue.record("Expected typed UI launch")
            return
        }
        #expect(scenario.id == .accessibilitySmoke)
        #expect(overrides == .init(
            contentSize: .accessibilityExtraExtraExtraLarge,
            layoutDirection: .rightToLeft,
            locale: .arabic,
            reduceMotion: true
        ))
    }

    @Test
    func preparedAccessibilityScenarioOwnsOnlyItsCatalogSmokeScript() throws {
        let configuration = AppLaunchConfiguration(arguments: [
            "AppTemplate", "--ui-testing", "--ui-test-scenario", "accessibility-smoke"
        ])
        guard case let .uiTesting(scenario, _) = configuration else {
            Issue.record("Expected prepared accessibility scenario")
            return
        }
        #expect(scenario.appState == .initial)
        #expect(scenario.remoteSteps.count == 2)
        #expect(scenario.imageSeed.steps.isEmpty)
    }

    @Test(arguments: [
        ["AppTemplate", "--ui-test-content-size", "standard"],
        ["AppTemplate", "--ui-test-layout-direction", "leftToRight"],
        ["AppTemplate", "--ui-test-locale", "ar_SA"],
        ["AppTemplate", "--ui-test-reduce-motion"]
    ])
    func presentationOptionsWithoutAValidScenarioFailClosed(_ arguments: [String]) {
        guard case .invalidUITesting = AppLaunchConfiguration(arguments: arguments) else {
            Issue.record("Presentation override escaped the UI-test launch gate")
            return
        }
    }
}
