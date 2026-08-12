import Foundation

nonisolated enum UserDefaultsPhysicalKind: Equatable, Sendable {
    case bool, int, float, double, string, data, date
}

nonisolated enum UserDefaultsEncodedValue: Sendable {
    case bool(Bool), int(Int), float(Float), double(Double)
    case string(String), data(Data), date(Date)
}
