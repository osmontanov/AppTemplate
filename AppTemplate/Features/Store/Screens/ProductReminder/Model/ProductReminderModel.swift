import Foundation

nonisolated
enum ProductReminderField: Hashable, Sendable {
    case interval
    case calendarDate
}

nonisolated
struct ProductReminderCalendarPresentation: Equatable, Sendable {
    let date: String
    let time: String
    let timeZone: String
}

nonisolated
struct ProductReminderModel: Equatable, Sendable {

    var selection: ProductReminderSelection
    var intervalText: String
    var calendarDate: Date
    var calendarTimeZone: TimeZone

    func firstInvalidField(now: Date) -> ProductReminderField? {
        switch selection {
        case .quickTest:
            return nil
        case let .interval(_, repeats):
            guard let seconds = TimeInterval(intervalText),
                  seconds.isFinite,
                  (1...ProductReminderPolicy.maximumInterval).contains(seconds),
                  !repeats || seconds >= ProductReminderPolicy.minimumRepeatingInterval
            else {
                return .interval
            }
            return nil
        case .calendar:
            guard calendarDate > now else { return .calendarDate }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = calendarTimeZone
            guard let maximum = calendar.date(byAdding: .year, value: 1, to: now),
                  calendarDate <= maximum
            else {
                return .calendarDate
            }
            return nil
        }
    }

    func calendarPresentation(locale: Locale) -> ProductReminderCalendarPresentation {
        var dateStyle = Date.FormatStyle(date: .long, time: .omitted).locale(locale)
        dateStyle.timeZone = calendarTimeZone
        var timeStyle = Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
        timeStyle.timeZone = calendarTimeZone
        var timeZoneStyle = Date.FormatStyle()
            .timeZone(.specificName(.long))
            .locale(locale)
        timeZoneStyle.timeZone = calendarTimeZone
        return ProductReminderCalendarPresentation(
            date: calendarDate.formatted(dateStyle),
            time: calendarDate.formatted(timeStyle),
            timeZone: calendarDate.formatted(timeZoneStyle)
        )
    }

    func selectionForScheduling() -> ProductReminderSelection {
        switch selection {
        case .quickTest:
            return .quickTest
        case let .interval(_, repeats):
            return .interval(seconds: TimeInterval(intervalText) ?? 0, repeats: repeats)
        case .calendar:
            return .calendar(date: calendarDate, timeZone: calendarTimeZone)
        }
    }
}
