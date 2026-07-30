import OSLog
import SwiftUI

struct AppSceneView: View {
    @Environment(SessionStore.self) private var sessionStore
    let appFlowRouter: AppFlowRouter
    let dependencies: AppDependencies

    @State private var lifecycle: AppSceneNavigationLifecycle
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?

    init(appFlowRouter: AppFlowRouter, dependencies: AppDependencies) {
        self.appFlowRouter = appFlowRouter
        self.dependencies = dependencies
        _lifecycle = State(
            initialValue: AppSceneNavigationLifecycle(
                appFlowRouter: appFlowRouter
            )
        )
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowRouter,
            router: lifecycle.router,
            dependencies: dependencies
        )
            .task {
                if let snapshot = lifecycle.restore(
                    from: encodedSnapshot,
                    applying: appFlowRouter.transition
                ) {
                    persist(snapshot)
                }
                await sessionStore.start()
                appFlowRouter.synchronizeSession(sessionStore.phase)
                _ = lifecycle.apply(appFlowRouter.transition)
            }
            .onChange(of: lifecycle.router.snapshot) { _, snapshot in
                guard lifecycle.hasRestored else {
                    return
                }
                persist(snapshot)
            }
            .onChange(of: sessionStore.phase) { _, phase in
                appFlowRouter.synchronizeSession(phase)
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
