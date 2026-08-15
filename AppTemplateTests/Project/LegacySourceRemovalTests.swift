import CryptoKit
import Foundation
import Testing

struct LegacySourceRemovalTests {
    @Test
    func everyAuditedLegacyPathIsAbsent() throws {
        let paths = try LegacySourceManifest.loadAuditedPaths()

        #expect(paths.count == 152)
        #expect(
            LegacySourceManifest.sha256(paths)
                == "f93e89b71482728228705ff70678450b32fc3a179dee371de45a6857c933a9e8"
        )
        for path in paths {
            #expect(
                !FileManager.default.fileExists(
                    atPath: LegacySourceManifest.projectRoot + "/" + path
                )
            )
        }
    }

    @Test
    func legacyManifestContractIsFrozenBeforeDeletion() throws {
        let paths = try LegacySourceManifest.loadAuditedPaths()

        #expect(paths.count == 152)
        #expect(
            LegacySourceManifest.sha256(paths)
                == "f93e89b71482728228705ff70678450b32fc3a179dee371de45a6857c933a9e8"
        )
    }
}

private enum LegacySourceManifest {
    static let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .path

    static func loadAuditedPaths() throws -> [String] {
        let manifestURL = URL(fileURLWithPath: projectRoot)
            .appending(path: "Scripts/connected-mini-store-legacy-paths.txt")
        let data = try Data(contentsOf: manifestURL)
        let source = try #require(String(data: data, encoding: .utf8))
        #expect(source.hasSuffix("\n"))
        let paths = source.split(separator: "\n").map(String.init)
        #expect(paths == paths.sorted())
        #expect(Set(paths).count == paths.count)
        return paths
    }

    static func sha256(_ paths: [String]) -> String {
        let serialized = paths.joined(separator: "\n") + "\n"
        return SHA256.hash(data: Data(serialized.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
