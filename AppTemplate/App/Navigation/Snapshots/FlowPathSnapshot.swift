import Foundation
import SwiftUI

struct FlowPathSnapshot: Codable, Equatable, Sendable {
    let data: Data?

    init(path: NavigationPath) {
        guard let representation = path.codable else {
            data = nil
            return
        }
        data = try? JSONEncoder().encode(representation)
    }

    var restoredPath: NavigationPath? {
        guard let data,
              let representation = try? JSONDecoder().decode(
                  NavigationPath.CodableRepresentation.self,
                  from: data
              ) else {
            return nil
        }
        return NavigationPath(representation)
    }

    var isRestorable: Bool {
        data != nil
    }
}
