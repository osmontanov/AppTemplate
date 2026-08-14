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
        let store = UITab(
            title: "Same localized title",
            image: nil,
            identifier: AppSection.store.presentationIdentifier
        ) { _ in
            UIViewController()
        }
        let controller = UITabBarController(tabs: [store])

        #expect(
            TabAccessibilityIdentifierInstaller.install(in: controller)
                == Set([.services])
        )
        #expect(
            store.accessibilityIdentifier
                == AppSection.store.accessibilityIdentifier
        )
    }
}
#endif
