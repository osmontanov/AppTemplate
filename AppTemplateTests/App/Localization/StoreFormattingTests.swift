import Foundation
import Testing
@testable import AppTemplate

struct StoreFormattingTests {
    @Test
    func usdFormattingUsesTheSuppliedLocale() {
        let value = Decimal(string: "19.5")!

        #expect(StoreFormatting.priceUSD(value, locale: Locale(identifier: "en_US")) == "$19.50")
        #expect(
            StoreFormatting.priceUSD(value, locale: Locale(identifier: "de_DE"))
                .contains("19,50")
        )
        #expect(
            StoreFormatting.priceUSD(value, locale: Locale(identifier: "ar_SA"))
                != StoreFormatting.priceUSD(value, locale: Locale(identifier: "en_US"))
        )
    }

    @Test
    func dateTimeFormattingUsesTheSuppliedLocaleAndTimeZone() {
        let value = Date(timeIntervalSince1970: 0)
        let utc = TimeZone(secondsFromGMT: 0)!
        let bishkek = TimeZone(secondsFromGMT: 6 * 60 * 60)!
        let enUS = Locale(identifier: "en_US")

        let utcEnglish = StoreFormatting.dateTime(value, locale: enUS, timeZone: utc)
        let bishkekEnglish = StoreFormatting.dateTime(value, locale: enUS, timeZone: bishkek)
        let german = StoreFormatting.dateTime(
            value,
            locale: Locale(identifier: "de_DE"),
            timeZone: utc
        )
        let arabic = StoreFormatting.dateTime(
            value,
            locale: Locale(identifier: "ar_SA"),
            timeZone: utc
        )

        #expect(utcEnglish != bishkekEnglish)
        #expect(utcEnglish != german)
        #expect(utcEnglish != arabic)
    }
}
