import Foundation
import Testing
@testable import AppTemplate

struct DeepLinkParserTests {
    private let parser = DeepLinkParser()

    @Test(arguments: [
        ("apptemplate://home", NavigationIntent.selectSection(.home)),
        ("apptemplate://browse", NavigationIntent.selectSection(.browse)),
        ("apptemplate://settings", NavigationIntent.selectSection(.settings)),
        ("apptemplate://browse/item/swiftui", NavigationIntent.browseItem(id: "swiftui"))
    ])
    func parsesSupportedURLs(rawURL: String, expected: NavigationIntent) throws {
        let url = try #require(URL(string: rawURL))
        #expect(parser.parse(url) == .success(expected))
    }

    @Test
    func rejectsUnsupportedScheme() throws {
        let url = try #require(URL(string: "https://example.com/browse"))
        #expect(parser.parse(url) == .failure(.unsupportedScheme))
    }

    @Test(arguments: ["apptemplate://unknown", "apptemplate://browse/other/swiftui"])
    func rejectsUnknownDestinations(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))
        #expect(parser.parse(url) == .failure(.unknownDestination))
    }

    @Test(arguments: [
        ("apptemplate://browse/item/%25", "%"),
        ("apptemplate://browse/item/%2F", "/"),
        ("apptemplate://browse/item/%252F", "%2F")
    ])
    func decodesEachPercentEncodedPathSegmentExactlyOnce(
        rawURL: String,
        expectedID: String
    ) throws {
        let url = try #require(URL(string: rawURL))
        #expect(parser.parse(url) == .success(.browseItem(id: expectedID)))
    }

    @Test(arguments: [
        ("apptemplate://browse/item/%", "%"),
        ("apptemplate://browse/item/%2", "%2")
    ])
    func parsesMalformedEscapesAfterFoundationCanonicalizesThem(
        rawURL: String,
        expectedID: String
    ) throws {
        let url = try #require(URL(string: rawURL))
        #expect(parser.parse(url) == .success(.browseItem(id: expectedID)))
    }
}
