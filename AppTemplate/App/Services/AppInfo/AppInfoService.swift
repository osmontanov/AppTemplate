import Foundation

nonisolated
struct AppInfoService: IAppInfoService {
    let displayName: String
    let version: String

    init(bundle: Bundle = .main) {
        displayName = (bundle.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "AppTemplate"
        version = (bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String)
            ?? "1.0"
    }

    init(displayName: String, version: String) {
        self.displayName = displayName
        self.version = version
    }
}
