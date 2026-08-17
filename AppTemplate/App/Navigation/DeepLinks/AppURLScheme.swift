nonisolated
enum AppURLScheme {
    // Single in-code source of truth for the custom URL scheme. Info.plist
    // registers the same value through APP_URL_SCHEME in Config/Template.xcconfig;
    // change both together when renaming the template.
    static let scheme = "apptemplate"
}
