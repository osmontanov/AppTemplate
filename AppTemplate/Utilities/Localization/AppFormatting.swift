import Foundation

nonisolated enum AppFormatting {
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
