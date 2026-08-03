#if os(iOS)
import SwiftUI
import UIKit

struct TabAccessibilityIdentifierInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InstallerViewController {
        InstallerViewController()
    }

    func updateUIViewController(
        _ uiViewController: InstallerViewController,
        context: Context
    ) {
        uiViewController.installIfPossible()
    }

    @discardableResult
    @MainActor
    static func install(
        in tabBarController: UITabBarController
    ) -> Set<AppSection> {
        var unresolved = Set<AppSection>()

        for section in AppSection.allCases {
            guard let tab = tabBarController.tab(
                forIdentifier: section.presentationIdentifier
            ) else {
                unresolved.insert(section)
                continue
            }
            tab.accessibilityIdentifier = section.accessibilityIdentifier
            tab.viewController?.tabBarItem.accessibilityIdentifier =
                section.accessibilityIdentifier
        }
        return unresolved
    }
}

extension TabAccessibilityIdentifierInstaller {
    final class InstallerViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installIfPossible()
        }

        func installIfPossible() {
            guard let tabBarController else {
                return
            }
            TabAccessibilityIdentifierInstaller.install(
                in: tabBarController
            )
        }
    }
}
#endif
