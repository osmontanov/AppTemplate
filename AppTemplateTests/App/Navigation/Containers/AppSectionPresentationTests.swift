import Testing
@testable import AppTemplate

@MainActor
struct AppSectionPresentationTests {
    @Test(arguments: [
        (AppSection.home, "house", "app.section.home", "tab.home"),
        (
            AppSection.browse,
            "square.grid.2x2",
            "app.section.browse",
            "tab.browse"
        ),
        (
            AppSection.projects,
            "folder",
            "app.section.projects",
            "tab.projects"
        ),
        (
            AppSection.settings,
            "gearshape",
            "app.section.settings",
            "tab.settings"
        )
    ])
    func sectionMetadataIsStable(
        section: AppSection,
        systemImage: String,
        presentationIdentifier: String,
        accessibilityIdentifier: String
    ) {
        #expect(section.systemImage == systemImage)
        #expect(section.presentationIdentifier == presentationIdentifier)
        #expect(section.accessibilityIdentifier == accessibilityIdentifier)
    }

    @Test
    func sectionIdentifiersAreUnique() {
        let presentationIdentifiers = AppSection.allCases.map(
            \.presentationIdentifier
        )
        let accessibilityIdentifiers = AppSection.allCases.map(
            \.accessibilityIdentifier
        )

        #expect(
            Set(presentationIdentifiers).count == AppSection.allCases.count
        )
        #expect(
            Set(accessibilityIdentifiers).count == AppSection.allCases.count
        )
    }
}
