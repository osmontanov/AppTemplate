import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppSectionPresentationTests {
    @Test(arguments: [
        (AppSection.store, "Store", "storefront", "app.section.store", "tab.store"),
        (
            AppSection.services,
            "Services",
            "wrench.and.screwdriver",
            "app.section.services",
            "tab.services"
        )
    ])
    func sectionMetadataIsStable(
        section: AppSection,
        title: String,
        systemImage: String,
        presentationIdentifier: String,
        accessibilityIdentifier: String
    ) {
        #expect(String(localized: section.localizedTitle) == title)
        #expect(section.systemImage == systemImage)
        #expect(section.presentationIdentifier == presentationIdentifier)
        #expect(section.accessibilityIdentifier == accessibilityIdentifier)
    }

    @Test
    func mainContainsExactlyStoreAndServicesWithUniqueIdentifiers() {
        #expect(AppSection.allCases == [.store, .services])
        #expect(Set(AppSection.allCases.map(\.presentationIdentifier)).count == 2)
        #expect(Set(AppSection.allCases.map(\.accessibilityIdentifier)).count == 2)
    }
}
