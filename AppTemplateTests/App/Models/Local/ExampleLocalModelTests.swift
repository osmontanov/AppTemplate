import Foundation
import Testing
@testable import AppTemplate

struct ExampleLocalModelTests {
    @Test
    func recordSurvivesPersistenceRoundTrip() throws {
        let original = ExampleRecord(
            id: "local-42",
            payload: "Persisted example"
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            ExampleRecord.self,
            from: data
        )

        #expect(restored == original)
    }

    @Test
    func recordIdentityRemainsExact() {
        let record = ExampleRecord(id: " local-42 ", payload: "value")

        #expect(record.id == " local-42 ")
    }
}
