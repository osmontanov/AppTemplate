import Foundation
import Testing
@testable import AppTemplate

struct DeepLinkParserTests {
    private let parser = DeepLinkParser()

    @Test
    func injectedSchemeAcceptsOnlyThatScheme() throws {
        let parser = DeepLinkParser(scheme: "renamed-template")

        #expect(
            parser.parse(
                try #require(URL(string: "renamed-template://settings"))
            ) == .success(.selectSection(.settings))
        )
        #expect(
            parser.parse(
                try #require(URL(string: "apptemplate://settings"))
            ) == .failure(.unsupportedScheme)
        )
    }

    @Test(arguments: [
        ("apptemplate://home", NavigationIntent.selectSection(.home)),
        ("apptemplate://browse", NavigationIntent.selectSection(.browse)),
        (
            "apptemplate://projects",
            NavigationIntent.openSectionRoot(.projects)
        ),
        (
            "apptemplate://projects/project/project-1",
            NavigationIntent.project(id: "project-1")
        ),
        (
            "apptemplate://projects/project/project-1/task/task-1",
            NavigationIntent.projectTask(
                projectID: "project-1",
                taskID: "task-1"
            )
        ),
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
        "apptemplate://browse//item/swiftui",
        "apptemplate://browse/item//swiftui",
        "apptemplate://home/",
        "apptemplate://browse/",
        "apptemplate://settings/",
        "apptemplate://browse/item/",
        "apptemplate://browse/item/swiftui/",
        "apptemplate://projects/project",
        "apptemplate://projects/project/",
        "apptemplate://projects/project/project-1/task",
        "apptemplate://projects/project/project-1/task/"
    ])
    func rejectsEmptyPathSegments(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))
        #expect(parser.parse(url) == .failure(.unknownDestination))
    }

    @Test
    func rejectsProjectsURLsWithExtraPathComponents() throws {
        let url = try #require(
            URL(
                string: "apptemplate://projects/project/project-1/task/task-1/extra"
            )
        )

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
