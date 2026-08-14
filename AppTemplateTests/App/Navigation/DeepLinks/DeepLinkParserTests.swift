import Foundation
import Testing
@testable import AppTemplate

struct DeepLinkParserTests {
    @Test(arguments: [
        ("apptemplate://store", NavigationIntent.openStoreRoot),
        ("apptemplate://services", NavigationIntent.openServicesRoot)
    ])
    func parsesOnlyTaskOneRoots(rawURL: String, expected: NavigationIntent) throws {
        #expect(DeepLinkParser().parse(try #require(URL(string: rawURL))) == .success(expected))
    }

    @Test(arguments: [
        "apptemplate://store/product/1",
        "apptemplate://services/app-info",
        "apptemplate://home",
        "apptemplate://store/",
        "https://store"
    ])
    func rejectsNonRootDestinations(rawURL: String) throws {
        #expect(DeepLinkParser().parse(try #require(URL(string: rawURL))).isFailure)
    }

    @Test
    func injectedSchemeAcceptsOnlyThatScheme() throws {
        let parser = DeepLinkParser(scheme: "renamed-template")
        #expect(parser.parse(try #require(URL(string: "renamed-template://store"))) == .success(.openStoreRoot))
        #expect(parser.parse(try #require(URL(string: "apptemplate://store"))) == .failure(.unsupportedScheme))
    }
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { true } else { false }
    }
}
