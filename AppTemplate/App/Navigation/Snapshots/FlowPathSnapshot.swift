import Foundation
import SwiftUI

struct FlowPathSnapshot: Codable, Equatable, Sendable {
    let data: Data?

    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.data != rhs.data else {
            return true
        }
        guard let lhsComponents = lhs.semanticComponents,
              let rhsComponents = rhs.semanticComponents else {
            return false
        }
        return lhsComponents == rhsComponents
    }

    init(path: NavigationPath) {
        guard let representation = path.codable else {
            data = nil
            return
        }
        data = try? JSONEncoder().encode(representation)
    }

    init(restorationData: Data?) {
        data = restorationData
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

    private var semanticComponents: [Data]? {
        guard let data,
              let components = try? JSONDecoder().decode(
                  [String].self,
                  from: data
              ),
              components.count.isMultiple(of: 2) else {
            return nil
        }
        var semanticComponents: [Data] = []
        semanticComponents.reserveCapacity(components.count)
        for index in components.indices {
            let component = components[index]
            if index.isMultiple(of: 2) {
                guard !component.isEmpty else {
                    return nil
                }
                semanticComponents.append(Data(component.utf8))
            } else {
                guard let canonical = Self.canonicalize(component) else {
                    return nil
                }
                semanticComponents.append(canonical)
            }
        }
        return semanticComponents
    }

    private static func canonicalize(_ component: String) -> Data? {
        let original = Data(component.utf8)
        guard let object = try? JSONSerialization.jsonObject(
            with: original,
            options: .fragmentsAllowed
        ),
              let canonical = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.fragmentsAllowed, .sortedKeys]
              ) else {
            return nil
        }
        return canonical
    }
}
