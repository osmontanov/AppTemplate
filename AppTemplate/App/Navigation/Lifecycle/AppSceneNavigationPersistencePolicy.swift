import Foundation

nonisolated
enum AppSceneNavigationPersistencePolicy: Equatable, Sendable {
    case restored
    case ephemeral

    var allowsSnapshotPersistence: Bool {
        self == .restored
    }

    func restorationData(from storedData: Data?) -> Data? {
        switch self {
        case .restored:
            storedData
        case .ephemeral:
            nil
        }
    }
}
