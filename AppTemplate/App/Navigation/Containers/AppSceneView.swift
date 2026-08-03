import OSLog
import SwiftUI

struct AppSceneView: View {
    let appFlowCoordinator: AppFlowCoordinator
    let settings: SettingsDependencies
    private let navigationPersistencePolicy:
        AppSceneNavigationPersistencePolicy

    @State private var lifecycle: AppSceneNavigationLifecycle
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?

    private var appFlowRouter: AppFlowRouter {
        appFlowCoordinator.appFlowRouter
    }

    init(
        appFlowCoordinator: AppFlowCoordinator,
        settings: SettingsDependencies,
        navigationPersistencePolicy:
            AppSceneNavigationPersistencePolicy = .restored
    ) {
        self.appFlowCoordinator = appFlowCoordinator
        self.settings = settings
        self.navigationPersistencePolicy = navigationPersistencePolicy
        _lifecycle = State(
            initialValue: AppSceneNavigationLifecycle(
                appFlowRouter: appFlowCoordinator.appFlowRouter,
                appFlowCoordinator: appFlowCoordinator
            )
        )
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowRouter,
            router: lifecycle.router,
            settings: settings
        )
            .task {
                let restorationData = navigationPersistencePolicy.restorationData(
                    from: encodedSnapshot
                )
                if lifecycle.restore(
                    from: restorationData,
                    applying: appFlowRouter.transition
                ) != nil {
                    persist()
                }
            }
            .onChange(of: lifecycle.router.snapshot) { _, _ in
                guard lifecycle.hasRestored else {
                    return
                }
                persist()
            }
            .onChange(of: appFlowRouter.transition) { _, transition in
                guard lifecycle.hasRestored else {
                    return
                }
                _ = lifecycle.apply(transition)
                persist()
            }
            .onOpenURL { url in
                if lifecycle.receive(url) != nil {
                    persist()
                }
            }
    }

    private func persist() {
        guard navigationPersistencePolicy.allowsSnapshotPersistence,
              let snapshot = lifecycle.snapshotForPersistence
        else {
            return
        }
        do {
            guard let encoding = try NavigationSnapshotCodec.encodingIfChanged(
                snapshot,
                comparedTo: encodedSnapshot
            ) else {
                return
            }
            encodedSnapshot = encoding
        } catch {
            Logger.navigation.error(
                "Failed to encode navigation snapshot: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
