#if os(iOS)
import Testing
import UIKit
@testable import AppTemplate

@MainActor
struct TabAccessibilityIdentifierInstallerTests {
    @Test
    func installationUsesStableIdentifiersAndPreservesSelection() throws {
        let tabs = AppSection.allCases.map { section in
            UITab(
                title: "Same localized title",
                image: nil,
                identifier: section.presentationIdentifier
            ) { _ in
                UIViewController()
            }
        }
        let controller = UITabBarController(tabs: tabs)
        controller.selectedTab = tabs[1]
        let selection = controller.selectedTab

        #expect(
            TabAccessibilityIdentifierInstaller.install(
                in: controller
            ).isEmpty
        )
        #expect(
            TabAccessibilityIdentifierInstaller.install(
                in: controller
            ).isEmpty
        )
        #expect(controller.selectedTab === selection)

        for section in AppSection.allCases {
            let tab = try #require(
                controller.tab(
                    forIdentifier: section.presentationIdentifier
                )
            )
            #expect(
                tab.accessibilityIdentifier
                    == section.accessibilityIdentifier
            )
            #expect(
                tab.viewController?.tabBarItem.accessibilityIdentifier
                    == section.accessibilityIdentifier
            )
        }
    }

    @Test
    func missingTabsAreReportedWithoutPositionalFallback() {
        let home = UITab(
            title: "Same localized title",
            image: nil,
            identifier: AppSection.home.presentationIdentifier
        ) { _ in
            UIViewController()
        }
        let controller = UITabBarController(tabs: [home])

        #expect(
            TabAccessibilityIdentifierInstaller.install(in: controller)
                == Set([.browse, .projects, .settings])
        )
        #expect(
            home.accessibilityIdentifier
                == AppSection.home.accessibilityIdentifier
        )
    }
}
#endif
