import OSLog
import SwiftUI

struct AppSceneView: View {
    @State private var router = AppRouter()
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?
    @State private var hasRestored = false

    var body: some View {
        AppRootView(router: router)
            .task {
                guard !hasRestored else {
                    return
                }

                let result = router.restore(from: encodedSnapshot)
                hasRestored = true

                if case .reset = result {
                    persist(router.snapshot)
                }
            }
            .onChange(of: router.snapshot) { _, snapshot in
                guard hasRestored else {
                    return
                }
                persist(snapshot)
            }
            .onOpenURL { url in
                switch DeepLinkParser().parse(url) {
                case let .success(intent):
                    _ = router.handle(intent)
                case let .failure(error):
                    router.resetNavigation()
                    Logger.navigation.error(
                        "Rejected deep link: \(String(describing: error), privacy: .public)"
                    )
                }
            }
    }

    private func persist(_ snapshot: NavigationSnapshot) {
        do {
            encodedSnapshot = try NavigationSnapshotCodec.encode(snapshot)
        } catch {
            Logger.navigation.error(
                "Failed to encode navigation snapshot: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
