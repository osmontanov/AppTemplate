import Foundation

// Every user-visible string resolves through this type, so the catalog has a
// single producer. Two overloads, one rule: pass the English text itself, and
// reach for an explicit key plus `defaultValue` only when interpolation would
// make different strings share one format key — "\(a): \(b)" collapses to
// "%@: %@" for every string shaped that way.
nonisolated enum AppText {
    private static let table = "AppText"

    static func resource(
        _ keyAndValue: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(keyAndValue, table: table)
    }

    static func string(
        _ keyAndValue: String.LocalizationValue,
        locale: Locale = .current
    ) -> String {
        var resource = resource(keyAndValue)
        resource.locale = locale
        return String(localized: resource)
    }

    static func resource(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, defaultValue: defaultValue, table: table)
    }

    static func string(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        locale: Locale = .current
    ) -> String {
        String(
            localized: key,
            defaultValue: defaultValue,
            table: table,
            locale: locale
        )
    }
}
