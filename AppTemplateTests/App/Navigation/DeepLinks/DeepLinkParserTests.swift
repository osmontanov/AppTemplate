import Foundation
import Testing
@testable import AppTemplate

struct DeepLinkParserTests {
    @Test(arguments: [
        ("apptemplate://store", NavigationIntent.openStoreRoot),
        ("apptemplate://store/product/1", .openProduct(1)),
        ("apptemplate://store/product/42", .openProduct(42)),
        ("apptemplate://store/favorites", .openFavorites),
        ("apptemplate://store/profile", .openProfile),
        ("apptemplate://services", .openServicesRoot),
        ("apptemplate://services/app-state", .openService(.appState)),
        ("apptemplate://services/app-info", .openService(.appInfo)),
        ("apptemplate://services/user-defaults", .openService(.userDefaults)),
        ("apptemplate://services/keychain", .openService(.keychain)),
        ("apptemplate://services/local-database", .openService(.localDatabase)),
        ("apptemplate://services/remote-api", .openService(.remoteAPI)),
        ("apptemplate://services/local-notifications", .openService(.localNotifications))
    ])
    func acceptsOnlyTypedStoreAndServicesDestinations(
        rawURL: String,
        expected: NavigationIntent
    ) throws {
        #expect(
            DeepLinkParser().parse(try #require(URL(string: rawURL)))
                == .success(expected)
        )
    }

    @Test(arguments: [
        ("https://store", DeepLinkError.invalidScheme),
        ("apptemplate://user@store", .credentialsNotAllowed),
        ("apptemplate://user:password@store", .credentialsNotAllowed),
        ("apptemplate://store:443", .portNotAllowed),
        ("apptemplate://store?x=1", .queryNotAllowed),
        ("apptemplate://store?", .queryNotAllowed),
        ("apptemplate://store#fragment", .fragmentNotAllowed),
        ("apptemplate://store#", .fragmentNotAllowed),
        ("apptemplate://legacy/private", .unsupportedHost),
        ("apptemplate://home", .unsupportedHost),
        ("apptemplate://store/", .invalidSegments),
        ("apptemplate://store//", .invalidSegments),
        ("apptemplate://store/product/1/extra", .invalidSegments),
        ("apptemplate://store/product/%2F", .invalidProductID),
        ("apptemplate://services/", .invalidSegments),
        ("apptemplate://services/app-info/", .invalidSegments),
        ("apptemplate://services/private", .invalidSegments),
        ("apptemplate://services/app-info/extra", .invalidSegments),
        ("apptemplate://store/product/0", .invalidProductID),
        ("apptemplate://store/product/-1", .invalidProductID),
        ("apptemplate://store/product/not-a-number", .invalidProductID),
        ("apptemplate://store/product/999999999999999999999999999999999999", .invalidProductID)
    ])
    func rejectsForbiddenComponentsAndMalformedDestinations(
        rawURL: String,
        expected: DeepLinkError
    ) throws {
        #expect(
            DeepLinkParser().parse(try #require(URL(string: rawURL)))
                == .failure(expected)
        )
    }

    @Test
    func validatesComponentsBeforeDestination() throws {
        let url = try #require(
            URL(string: "https://user@legacy:443/private?token=secret#fragment")
        )
        #expect(DeepLinkParser().parse(url) == .failure(.invalidScheme))

        let wrongHostWithCredentials = try #require(
            URL(string: "apptemplate://user@legacy/private")
        )
        #expect(
            DeepLinkParser().parse(wrongHostWithCredentials)
                == .failure(.credentialsNotAllowed)
        )
    }

    @Test
    func injectedSchemeAcceptsOnlyThatScheme() throws {
        let parser = DeepLinkParser(scheme: "renamed-template")
        #expect(
            parser.parse(
                try #require(URL(string: "renamed-template://store/product/7"))
            ) == .success(.openProduct(7))
        )
        #expect(
            parser.parse(try #require(URL(string: "apptemplate://store")))
                == .failure(.invalidScheme)
        )
    }
}
