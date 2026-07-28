# Neutral Local and Remote Model Examples Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the reserved Local and Remote model folders with four small, unrelated example value types and focused serialization tests.

**Architecture:** Remote examples model one-way transport boundaries: an encodable outgoing request and a decodable incoming response. Local examples model runtime lookup criteria and a persistable record. The four types are deliberately independent and are not connected to services, features, navigation, dependency injection, or each other.

**Tech Stack:** Swift, Foundation Codable APIs, Swift Concurrency, Swift Testing, Xcode 26, synchronized filesystem groups.

## Global Constraints

- Support iOS 26, iPadOS 26, and macOS 26.
- Add no external dependencies.
- Keep `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Declare all four plain values `nonisolated`, `Equatable`, and `Sendable`.
- Give `ExampleRequest` only `Encodable`; do not add `Decodable`.
- Give `ExampleResponse` only `Decodable`; do not add `Encodable`.
- Give `ExampleQuery` no serialization conformance.
- Do not add a dedicated `ExampleQuery` unit test: it has no behavior beyond
  its synthesized initializer and equality.
- Give `ExampleRecord` `Codable`.
- Do not reference domain models, state models, services, dependency injection, view models, views, navigation, or another example model.
- Do not add protocols, generic base models, mappers, conversion initializers, validation, or service methods.
- Remove each reserved `.gitkeep` when its folder receives real Swift files.
- Use synchronized filesystem groups; do not modify `AppTemplate.xcodeproj/project.pbxproj`.

## File Structure

Create:

- `AppTemplate/App/Models/Remote/ExampleRequest.swift`: outgoing encodable payload.
- `AppTemplate/App/Models/Remote/ExampleResponse.swift`: incoming decodable payload.
- `AppTemplate/App/Models/Local/ExampleQuery.swift`: runtime local lookup criteria.
- `AppTemplate/App/Models/Local/ExampleRecord.swift`: locally persistable value.
- `AppTemplateTests/App/Models/Remote/ExampleRemoteModelTests.swift`: Remote JSON boundary tests.
- `AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift`: Local value and persistence tests.

Delete:

- `AppTemplate/App/Models/Remote/.gitkeep`
- `AppTemplate/App/Models/Local/.gitkeep`

No existing Swift source file or Xcode project file is modified.

---

### Task 1: Add Independent Remote Model Examples

**Files:**

- Create: `AppTemplateTests/App/Models/Remote/ExampleRemoteModelTests.swift`
- Create: `AppTemplate/App/Models/Remote/ExampleRequest.swift`
- Create: `AppTemplate/App/Models/Remote/ExampleResponse.swift`
- Delete: `AppTemplate/App/Models/Remote/.gitkeep`

**Interfaces:**

- Consumes: `Foundation.JSONEncoder`, `Foundation.JSONDecoder`, and `Foundation.JSONSerialization`.
- Produces: `ExampleRequest(query: String, page: Int)` conforming to `Encodable`, `Equatable`, and `Sendable`.
- Produces: `ExampleResponse(id: String, title: String)` conforming to `Decodable`, `Equatable`, and `Sendable`.
- Dependency boundary: neither type references the other or any existing application type.

- [ ] **Step 1: Write the failing Remote boundary tests**

Create `AppTemplateTests/App/Models/Remote/ExampleRemoteModelTests.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct ExampleRemoteModelTests {
    @Test
    func requestEncodesExpectedPayload() throws {
        let request = ExampleRequest(query: "swift", page: 2)

        let data = try JSONEncoder().encode(request)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object.count == 2)
        #expect(object["query"] as? String == "swift")
        #expect(object["page"] as? Int == 2)
    }

    @Test
    func responseDecodesIncomingPayload() throws {
        let data = Data(
            #"{"id":"example-42","title":"Remote example"}"#.utf8
        )

        let response = try JSONDecoder().decode(
            ExampleResponse.self,
            from: data
        )

        #expect(
            response == ExampleResponse(
                id: "example-42",
                title: "Remote example"
            )
        )
    }
}
```

- [ ] **Step 2: Run the Remote suite and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ExampleRemoteModelTests
```

Expected: compilation fails because `ExampleRequest` and `ExampleResponse`
do not exist.

- [ ] **Step 3: Add the minimal Remote model implementations**

Create `AppTemplate/App/Models/Remote/ExampleRequest.swift`:

```swift
nonisolated struct ExampleRequest: Encodable, Equatable, Sendable {
    let query: String
    let page: Int
}
```

Create `AppTemplate/App/Models/Remote/ExampleResponse.swift`:

```swift
nonisolated struct ExampleResponse: Decodable, Equatable, Sendable {
    let id: String
    let title: String
}
```

Delete `AppTemplate/App/Models/Remote/.gitkeep`. Do not add custom coding
keys, initializers, validation, conversion methods, or relationships.

- [ ] **Step 4: Run the Remote suite and verify GREEN**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ExampleRemoteModelTests
```

Expected: exit 0 and both Remote tests pass.

- [ ] **Step 5: Verify the Remote examples remain independent**

Run:

```bash
! rg -n \
  'ExampleResponse|BrowseItem|Service|ViewModel|Route|Dependencies' \
  AppTemplate/App/Models/Remote/ExampleRequest.swift
! rg -n \
  'ExampleRequest|BrowseItem|Service|ViewModel|Route|Dependencies' \
  AppTemplate/App/Models/Remote/ExampleResponse.swift
```

Expected: both commands return no matches.

- [ ] **Step 6: Commit the Remote examples**

```bash
git add \
  AppTemplate/App/Models/Remote/.gitkeep \
  AppTemplate/App/Models/Remote/ExampleRequest.swift \
  AppTemplate/App/Models/Remote/ExampleResponse.swift \
  AppTemplateTests/App/Models/Remote/ExampleRemoteModelTests.swift
git commit -m "feat: add remote model examples"
```

---

### Task 2: Add Independent Local Model Examples

**Files:**

- Create: `AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift`
- Create: `AppTemplate/App/Models/Local/ExampleQuery.swift`
- Create: `AppTemplate/App/Models/Local/ExampleRecord.swift`
- Delete: `AppTemplate/App/Models/Local/.gitkeep`

**Interfaces:**

- Consumes: `Foundation.JSONEncoder` and `Foundation.JSONDecoder`.
- Produces: `ExampleQuery(searchText: String?, limit: Int)` conforming to `Equatable` and `Sendable`.
- Produces: `ExampleRecord(id: String, payload: String)` conforming to `Codable`, `Equatable`, and `Sendable`.
- Dependency boundary: neither type references the other or any existing application type.

- [ ] **Step 1: Write the failing Local persistence test**

Create `AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run the Local suite and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ExampleLocalModelTests
```

Expected: compilation fails because `ExampleQuery` and `ExampleRecord` do
not exist.

- [ ] **Step 3: Add the minimal Local model implementations**

Create `AppTemplate/App/Models/Local/ExampleQuery.swift`:

```swift
nonisolated struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let limit: Int
}
```

Create `AppTemplate/App/Models/Local/ExampleRecord.swift`:

```swift
nonisolated struct ExampleRecord: Codable, Equatable, Sendable {
    let id: String
    let payload: String
}
```

Delete `AppTemplate/App/Models/Local/.gitkeep`. Do not add persistence APIs,
database imports, custom initializers, validation, conversion methods, or
relationships.

- [ ] **Step 4: Run the Local suite and verify GREEN**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ExampleLocalModelTests
```

Expected: exit 0 and the Local persistence test passes.

- [ ] **Step 5: Verify the Local examples remain independent**

Run:

```bash
! rg -n \
  'ExampleRecord|BrowseItem|Service|ViewModel|Route|Dependencies' \
  AppTemplate/App/Models/Local/ExampleQuery.swift
! rg -n \
  'ExampleQuery|BrowseItem|Service|ViewModel|Route|Dependencies' \
  AppTemplate/App/Models/Local/ExampleRecord.swift
```

Expected: both commands return no matches.

- [ ] **Step 6: Verify project-file hygiene**

Run:

```bash
git diff --check
git diff --exit-code -- AppTemplate.xcodeproj/project.pbxproj
find AppTemplate/App/Models/Local AppTemplate/App/Models/Remote \
  -name .gitkeep -print
```

Expected:

- `git diff --check` exits 0;
- `project.pbxproj` has no diff;
- `find` prints nothing.

- [ ] **Step 7: Run the full macOS test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS'
```

Expected: exit 0.

- [ ] **Step 8: Run the full iOS/iPadOS-compatible test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: exit 0. The shared iOS target covers both iPhone and iPad device
families; these platform-neutral model files contain no device-specific
code.

- [ ] **Step 9: Commit the Local examples**

```bash
git add \
  AppTemplate/App/Models/Local/.gitkeep \
  AppTemplate/App/Models/Local/ExampleQuery.swift \
  AppTemplate/App/Models/Local/ExampleRecord.swift \
  AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift
git commit -m "feat: add local model examples"
```
