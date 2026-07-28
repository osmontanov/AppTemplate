import Testing
@testable import AppTemplate

struct BrowseServiceTests {
    @Test
    func itemsPreserveInputOrderAndLookupUsesStableID() async throws {
        let first = BrowseItem(id: "first", title: "First", summary: "One")
        let second = BrowseItem(id: "second", title: "Second", summary: "Two")
        let service: any IBrowseService = BrowseService(
            items: [first, second]
        )

        let items = try await service.items()
        let item = try await service.item(id: second.id)

        #expect(items == [first, second])
        #expect(item == second)
    }
}
