import OSLog
import SwiftUI

struct AppSceneView: View {
    let appFlowCoordinator: AppFlowCoordinator

    @State private var lifecycle: AppSceneNavigationLifecycle
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?

    private var appFlowRouter: AppFlowRouter {
        appFlowCoordinator.appFlowRouter
    }

    init(appFlowCoordinator: AppFlowCoordinator) {
        self.appFlowCoordinator = appFlowCoordinator
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
            router: lifecycle.router
        )
            .task {
                if let snapshot = lifecycle.restore(
                    from: encodedSnapshot,
                    applying: appFlowRouter.transition
                ) {
                    persist(snapshot)
                }
            }
            .onChange(of: lifecycle.router.snapshot) { _, snapshot in
                guard lifecycle.hasRestored else {
                    return
                }
                persist(snapshot)
            }
            .onChange(of: appFlowRouter.transition) { _, transition in
                guard lifecycle.hasRestored else {
                    return
                }
                _ = lifecycle.apply(transition)
                persist(lifecycle.router.snapshot)
            }
            .onOpenURL { url in
                if let snapshot = lifecycle.receive(url) {
                    persist(snapshot)
                }
            }
    }

    private func persist(_ snapshot: NavigationSnapshot) {
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
