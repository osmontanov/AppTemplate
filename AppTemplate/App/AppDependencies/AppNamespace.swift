nonisolated
enum AppNamespace {
    // Renaming the template starts here: these two values name the app's
    // UserDefaults suite and Keychain service, and the lab variants that keep
    // the Services screens isolated from production data.
    static let primary = "AppTemplate"
    static let servicesLab = primary + ".ServicesLab"
}
