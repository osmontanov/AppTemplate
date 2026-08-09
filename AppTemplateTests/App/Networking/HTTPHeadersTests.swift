import Testing
@testable import AppTemplate

struct HTTPHeadersTests {
    @Test
    func orderedWritesUseCaseInsensitiveLastWriteWins() {
        var headers: HTTPHeaders = [
            "Authorization": "Bearer old",
            "authorization": "Bearer new"
        ]
        headers.set("Bearer final", for: "AUTHORIZATION")

        #expect(headers["authorization"] == "Bearer final")
        #expect(headers.fields == [
            HTTPHeaders.Field(name: "AUTHORIZATION", value: "Bearer final")
        ])
    }

    @Test
    func equalityIgnoresPresentationSpellingAndFieldsUseCanonicalOrder() {
        let first: HTTPHeaders = ["X-Zebra": "z", "content-type": "application/json"]
        let second: HTTPHeaders = ["Content-Type": "application/json", "x-zebra": "z"]

        #expect(first == second)
        #expect(first.fields.map(\.name) == ["content-type", "X-Zebra"])
    }

    @Test
    func onlyASCIIHTTPTokenNamesAreValidAndInvalidLookupIsNil() {
        #expect(HTTPHeaders.isValidFieldName("!#$%&'*+-.^_`|~AZaz09"))
        #expect(!HTTPHeaders.isValidFieldName(""))
        #expect(!HTTPHeaders.isValidFieldName("bad name"))
        #expect(!HTTPHeaders.isValidFieldName("bad:name"))
        #expect(!HTTPHeaders.isValidFieldName("café"))

        let headers: HTTPHeaders = ["X-Valid": "yes"]
        #expect(headers["bad name"] == nil)
        #expect(headers["café"] == nil)
    }
}
