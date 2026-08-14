import Foundation

nonisolated enum StoreServicesText {
    nonisolated enum Key: String, CaseIterable, Sendable {
        case storeTitle
        case servicesTitle
        case why
        case preset
        case tryIt
        case expected
        case actual
        case resetDemoData
        case advanced
        case demoUSDAssumption
        case appWideImpact
    }

    static func resource(_ key: Key) -> LocalizedStringResource {
        LocalizedStringResource(
            String.LocalizationValue(key.rawValue),
            table: "StoreServices"
        )
    }

    static func resource(_ keyAndValue: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(keyAndValue, table: "StoreServices")
    }

    static func string(_ key: Key, locale: Locale = .current) -> String {
        var resource = resource(key)
        resource.locale = locale
        return String(localized: resource)
    }

    static func resource(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(
            key,
            defaultValue: defaultValue,
            table: "StoreServices"
        )
    }

    static func string(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        locale: Locale = .current
    ) -> String {
        String(
            localized: key,
            defaultValue: defaultValue,
            table: "StoreServices",
            locale: locale
        )
    }

    static func string(
        _ keyAndValue: String.LocalizationValue,
        locale: Locale = .current
    ) -> String {
        var resource = resource(keyAndValue)
        resource.locale = locale
        return String(localized: resource)
    }
}

nonisolated enum StoreFormatting {
    static func priceUSD(_ value: Decimal, locale: Locale) -> String {
        value.formatted(.currency(code: "USD").locale(locale))
    }

    static func dateTime(_ value: Date, locale: Locale, timeZone: TimeZone) -> String {
        value.formatted(
            Date.FormatStyle(
                date: .numeric,
                time: .shortened,
                locale: locale,
                timeZone: timeZone
            )
        )
    }
}
