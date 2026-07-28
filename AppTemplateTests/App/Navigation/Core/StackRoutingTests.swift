import Testing
@testable import AppTemplate

@MainActor
struct StackRoutingTests {
    @Test
    func pushPopReplaceAndPopToRoot() {
        let router = BrowseRouter()

        router.push(.item(id: "swiftui"))
        router.push(.item(id: "observation"))
        #expect(router.path == [.item(id: "swiftui"), .item(id: "observation")])

        #expect(router.pop() == .item(id: "observation"))
        router.replacePath(with: [.item(id: "routing")])
        #expect(router.path == [.item(id: "routing")])

        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test
    func featureRoutersKeepIndependentHistories() {
        let home = HomeRouter()
        let browse = BrowseRouter()
        let settings = SettingsRouter()

        home.push(.details)
        browse.push(.item(id: "swiftui"))
        settings.push(.about)

        #expect(home.path == [.details])
        #expect(browse.path == [.item(id: "swiftui")])
        #expect(settings.path == [.about])
    }
}
