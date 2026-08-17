import Foundation
import Testing
@testable import AppTemplate

struct AppFormattingTests {
    @Test
    func usdFormattingUsesTheSuppliedLocale() {
        let value = Decimal(string: "19.5")!

        #expect(AppFormatting.priceUSD(value, locale: Locale(identifier: "en_US")) == "$19.50")
        #expect(
            AppFormatting.priceUSD(value, locale: Locale(identifier: "de_DE"))
                .contains("19,50")
        )
        #expect(
            AppFormatting.priceUSD(value, locale: Locale(identifier: "ar_SA"))
                != AppFormatting.priceUSD(value, locale: Locale(identifier: "en_US"))
        )
    }

    @Test
    func dateTimeFormattingUsesTheSuppliedLocaleAndTimeZone() {
        let value = Date(timeIntervalSince1970: 0)
        let utc = TimeZone(secondsFromGMT: 0)!
        let bishkek = TimeZone(secondsFromGMT: 6 * 60 * 60)!
        let enUS = Locale(identifier: "en_US")

        let utcEnglish = AppFormatting.dateTime(value, locale: enUS, timeZone: utc)
        let bishkekEnglish = AppFormatting.dateTime(value, locale: enUS, timeZone: bishkek)
        let german = AppFormatting.dateTime(
            value,
            locale: Locale(identifier: "de_DE"),
            timeZone: utc
        )
        let arabic = AppFormatting.dateTime(
            value,
            locale: Locale(identifier: "ar_SA"),
            timeZone: utc
        )

        #expect(utcEnglish != bishkekEnglish)
        #expect(utcEnglish != german)
        #expect(utcEnglish != arabic)
    }
}
