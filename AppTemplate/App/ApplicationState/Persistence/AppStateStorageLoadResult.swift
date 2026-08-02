import Foundation

nonisolated
enum AppStateStorageLoadResult: Equatable, Sendable {
    case missing
    case data(Data)
    case invalidValue
}
