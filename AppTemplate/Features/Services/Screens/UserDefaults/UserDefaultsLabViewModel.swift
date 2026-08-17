import Foundation
import Observation

@MainActor
@Observable
final class UserDefaultsLabViewModel {
    private static let maximumDataBytes = 4_096
    private static let maximumHexCharacters = 8_192

    private let service: any IUserDefaultsService
    private(set) var actualResult: ServiceLabResult = .idle

    init(service: any IUserDefaultsService) {
        self.service = service
    }

    func save(_ kind: UserDefaultsLabKind) throws {
        do {
            switch kind {
            case .bool:
                try service.set(UserDefaultsLabFixtures.bool, for: UserDefaultsLabKeys.bool)
            case .int:
                try service.set(UserDefaultsLabFixtures.int, for: UserDefaultsLabKeys.int)
            case .float:
                try service.set(UserDefaultsLabFixtures.float, for: UserDefaultsLabKeys.float)
            case .double:
                try service.set(UserDefaultsLabFixtures.double, for: UserDefaultsLabKeys.double)
            case .string:
                try service.set(UserDefaultsLabFixtures.string, for: UserDefaultsLabKeys.string)
            case .data:
                try service.set(UserDefaultsLabFixtures.data, for: UserDefaultsLabKeys.data)
            case .date:
                try service.set(UserDefaultsLabFixtures.date, for: UserDefaultsLabKeys.date)
            case .codable:
                try service.set(UserDefaultsLabFixtures.codable, for: UserDefaultsLabKeys.codable)
            }
            actualResult = .success(AppText.string("Saved \(kind.title)."))
        } catch {
            actualResult = .failure(AppText.string("The demo value could not be saved."))
            throw error
        }
    }

    func read(
        _ kind: UserDefaultsLabKind,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) throws {
        do {
            actualResult = switch kind {
            case .bool:
                present(try service.value(for: UserDefaultsLabKeys.bool), label: kind.title)
            case .int:
                present(try service.value(for: UserDefaultsLabKeys.int), label: kind.title)
            case .float:
                present(try service.value(for: UserDefaultsLabKeys.float), label: kind.title)
            case .double:
                present(try service.value(for: UserDefaultsLabKeys.double), label: kind.title)
            case .string:
                present(try service.value(for: UserDefaultsLabKeys.string), label: kind.title)
            case .data:
                presentData(try service.value(for: UserDefaultsLabKeys.data))
            case .date:
                presentDate(
                    try service.value(for: UserDefaultsLabKeys.date),
                    locale: locale,
                    timeZone: timeZone
                )
            case .codable:
                presentCodable(try service.value(for: UserDefaultsLabKeys.codable))
            }
        } catch {
            actualResult = .failure(AppText.string("The demo value could not be read."))
            throw error
        }
    }

    func remove(_ kind: UserDefaultsLabKind) {
        switch kind {
        case .bool: service.remove(UserDefaultsLabKeys.bool)
        case .int: service.remove(UserDefaultsLabKeys.int)
        case .float: service.remove(UserDefaultsLabKeys.float)
        case .double: service.remove(UserDefaultsLabKeys.double)
        case .string: service.remove(UserDefaultsLabKeys.string)
        case .data: service.remove(UserDefaultsLabKeys.data)
        case .date: service.remove(UserDefaultsLabKeys.date)
        case .codable: service.remove(UserDefaultsLabKeys.codable)
        }
        actualResult = .success(AppText.string("Removed \(kind.title)."))
    }

    func resetDemoData() {
        for kind in UserDefaultsLabKind.allCases { removeWithoutPublishing(kind) }
        actualResult = .success(AppText.string("Reset only the eight UserDefaults demo values."))
    }

    private func removeWithoutPublishing(_ kind: UserDefaultsLabKind) {
        switch kind {
        case .bool: service.remove(UserDefaultsLabKeys.bool)
        case .int: service.remove(UserDefaultsLabKeys.int)
        case .float: service.remove(UserDefaultsLabKeys.float)
        case .double: service.remove(UserDefaultsLabKeys.double)
        case .string: service.remove(UserDefaultsLabKeys.string)
        case .data: service.remove(UserDefaultsLabKeys.data)
        case .date: service.remove(UserDefaultsLabKeys.date)
        case .codable: service.remove(UserDefaultsLabKeys.codable)
        }
    }

    private func present<Value>(_ value: Value?, label: String) -> ServiceLabResult {
        guard let value else { return .success(AppText.string("\(label): no value stored.")) }
        return .success(AppText.string(
            "services.userDefaults.value",
            defaultValue: "\(label): \(String(describing: value))"
        ))
    }

    private func presentData(_ data: Data?) -> ServiceLabResult {
        guard let data else { return .success(AppText.string("Data: no value stored.")) }
        guard data.count <= Self.maximumDataBytes else {
            return .failure(AppText.string("Data exceeds the 4,096-byte display limit."))
        }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        guard hex.count <= Self.maximumHexCharacters else {
            return .failure(AppText.string("Data exceeds the hexadecimal display limit."))
        }
        return .success(AppText.string("Data (\(data.count) bytes): \(hex)"))
    }

    private func presentDate(
        _ date: Date?,
        locale: Locale,
        timeZone: TimeZone
    ) -> ServiceLabResult {
        guard let date else { return .success(AppText.string("Date: no value stored.")) }
        let formatted = AppFormatting.dateTime(date, locale: locale, timeZone: timeZone)
        return .success(AppText.string(
            "services.userDefaults.dateValue",
            defaultValue: "Date: \(formatted)"
        ))
    }

    private func presentCodable(_ value: UserDefaultsLabCodable?) -> ServiceLabResult {
        guard let value else { return .success(AppText.string("Codable: no value stored.")) }
        return .success(AppText.string("Codable: number \(value.number), label \(value.label)"))
    }
}
