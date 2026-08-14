@MainActor
protocol ISceneNavigationActions: AnyObject {
    func presentation() -> SceneNavigationPresentation
    func resetNavigationInCurrentScene()
    func handleSampleIntent(_ intent: NavigationIntent)
    func recoverRejectedLink(_ action: DeepLinkRecoveryAction)
}
