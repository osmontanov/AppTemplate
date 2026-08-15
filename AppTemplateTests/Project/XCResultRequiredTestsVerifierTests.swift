import Foundation
import Testing

#if os(macOS)
import Darwin

struct XCResultRequiredTestsVerifierTests {
    @Test
    func passingRequiredTestExitsSuccessfully() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Suite","nodeIdentifier":"suite","result":"Passed","children":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed","children":[]}]}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status == 0)
        #expect(outcome.standardOutput.contains("Verified 1 required test"))
        #expect(outcome.standardError.isEmpty)
    }

    @Test
    func missingRequiredIdentifierFails() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.OtherTests/testOther","result":"Passed","children":[]}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Missing required test"))
    }

    @Test
    func duplicateSelectedManifestIdentifierFails() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed","children":[]}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\niphone\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Duplicate required identifier"))
    }

    @Test
    func duplicateResultIdentifierFails() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":2,"passedTests":2,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Suite","children":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"},{"nodeType":"Test Suite","children":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"}]}]}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Duplicate result identifier"))
    }

    @Test
    func failedTestFailsEvenWhenItIsNotRequired() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Failed","totalTestCount":2,"passedTests":1,"failedTests":1,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Suite","children":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"},{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.OtherTests/testFailure","result":"Failed"}]}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Failed test"))
    }

    @Test
    func skippedTestFailsWhenRejectingAnySkips() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":2,"passedTests":1,"failedTests":0,"skippedTests":1}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"},{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.OtherTests/testSkipped","result":"Skipped"}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\nall\tAppTemplateUITests.OtherTests/testSkipped\tallow-skip\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Skipped test"))
    }

    @Test
    func exactAllowlistedSkipPassesOnlyWithoutRejectAnySkips() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":2,"passedTests":1,"failedTests":0,"skippedTests":1}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"},{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.OtherTests/testSkipped","result":"Skipped"}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\nall\tAppTemplateUITests.OtherTests/testSkipped\tallow-skip\n",
            rejectAnySkips: false
        )

        #expect(outcome.status == 0)
    }

    @Test
    func malformedJSONFailsClosed() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes": ["#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Malformed tests JSON"))
    }

    @Test
    func missingSummarySchemaFieldFailsClosed() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Malformed summary JSON or schema"))
    }

    @Test
    func missingTestCaseIdentifierFailsClosed() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","result":"Passed"}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Malformed Test Case node schema"))
    }

    @Test
    func unknownTestStatusFailsClosed() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Flaky"}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Unknown test status"))
    }

    @Test
    func unknownSummaryStatusFailsClosed() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Incomplete","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Unknown summary status"))
    }

    @Test
    func summaryCountMismatchFailsClosed() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":2,"passedTests":2,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[{"nodeType":"Test Case","nodeIdentifier":"AppTemplateUITests.StoreJourneyTests/testCatalog","result":"Passed"}]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n"
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("Summary/result count mismatch"))
    }

    @Test
    func xcresulttoolCommandFailureFailsClosed() throws {
        let outcome = try XCResultVerifierFixture.run(
            summary: #"{"result":"Passed","totalTestCount":1,"passedTests":1,"failedTests":0,"skippedTests":0}"#,
            tests: #"{"testNodes":[]}"#,
            required: "all\tAppTemplateUITests.StoreJourneyTests/testCatalog\n",
            runnerExitStatus: 19
        )

        #expect(outcome.status != 0)
        #expect(outcome.standardError.contains("xcresulttool command failed"))
    }
}

private enum XCResultVerifierFixture {
    private struct FixtureFailure: Error, Sendable, CustomStringConvertible {
        let description: String
    }

    struct Outcome {
        let status: Int32
        let standardOutput: String
        let standardError: String
    }

    static func run(
        summary: String,
        tests: String,
        required: String,
        platform: String = "iphone",
        rejectAnySkips: Bool = true,
        runnerExitStatus: Int32 = 0
    ) throws -> Outcome {
        let manager = FileManager.default
        let root = manager.temporaryDirectory
            .appendingPathComponent("XCResultRequiredTestsVerifierTests-\(UUID().uuidString)")
        try manager.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: root) }

        let summaryURL = root.appendingPathComponent("summary.json")
        let testsURL = root.appendingPathComponent("tests.json")
        let requiredURL = root.appendingPathComponent("required.tsv")
        let resultURL = root.appendingPathComponent("Result ; literal.xcresult")
        let runnerURL: URL
        if let compiledRunner = try fixtureRunnerExecutableURL() {
            runnerURL = compiledRunner
        } else {
            runnerURL = root.appendingPathComponent("fixture-runner")
            try fixtureRunner.write(to: runnerURL, atomically: true, encoding: .utf8)
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: runnerURL.path)
        }
        try summary.write(to: summaryURL, atomically: true, encoding: .utf8)
        try tests.write(to: testsURL, atomically: true, encoding: .utf8)
        try required.write(to: requiredURL, atomically: true, encoding: .utf8)
        try manager.createDirectory(at: resultURL, withIntermediateDirectories: false)

        var environment = ProcessInfo.processInfo.environment
        environment["XCRESULT_REQUIRED_TESTS_RUNNER"] = runnerURL.path
        environment["XCRESULT_FIXTURE_SUMMARY"] = summaryURL.path
        environment["XCRESULT_FIXTURE_TESTS"] = testsURL.path
        environment["XCRESULT_FIXTURE_RESULT"] = resultURL.path
        environment["XCRESULT_FIXTURE_EXIT"] = String(runnerExitStatus)

        return try execute(
            executableURL: verifierExecutableURL(),
            arguments: [
                "--result", resultURL.path,
                "--required", requiredURL.path,
                "--platform", platform
            ] + (rejectAnySkips ? ["--reject-any-skips"] : []),
            environment: environment,
            timeout: 10
        )
    }

    private static func verifierExecutableURL() throws -> URL {
        try verifierExecutableResult.get()
    }

    private static func fixtureRunnerExecutableURL() throws -> URL? {
        try fixtureRunnerExecutableResult.get()
    }

    private static let verifierExecutableResult: Result<URL, FixtureFailure> = {
        do {
            return .success(try prepareVerifierExecutable())
        } catch let failure as FixtureFailure {
            return .failure(failure)
        } catch {
            return .failure(
                FixtureFailure(description: "Could not prepare verifier executable: \(error)")
            )
        }
    }()

    private static let fixtureRunnerExecutableResult: Result<URL?, FixtureFailure> = {
        do {
            return .success(try prepareFixtureRunnerExecutable())
        } catch let failure as FixtureFailure {
            return .failure(failure)
        } catch {
            return .failure(
                FixtureFailure(description: "Could not prepare fixture runner: \(error)")
            )
        }
    }()

    private static func prepareVerifierExecutable() throws -> URL {
        let manager = FileManager.default
        if let injectedPath = ProcessInfo.processInfo.environment[
            "XCRESULT_VERIFIER_TEST_EXECUTABLE"
        ] {
            guard manager.isExecutableFile(atPath: injectedPath) else {
                throw FixtureFailure(
                    description: "XCRESULT_VERIFIER_TEST_EXECUTABLE is not executable."
                )
            }
            return URL(fileURLWithPath: injectedPath)
        }

        if let preparedRoot = Bundle.main.object(
            forInfoDictionaryKey: "XCResultVerifierRoot"
        ) as? String {
            let preparedExecutableURL = URL(fileURLWithPath: preparedRoot)
                .appendingPathComponent("verifier")
            guard manager.isExecutableFile(atPath: preparedExecutableURL.path) else {
                throw FixtureFailure(
                    description: "The per-run verifier executable is not executable."
                )
            }
            return preparedExecutableURL
        }

        let preparedExecutableURL = manager.temporaryDirectory
            .appendingPathComponent("AppTemplate-XCResultRequiredTestsVerifier")
            .appendingPathComponent("verifier")
        if manager.isExecutableFile(atPath: preparedExecutableURL.path) {
            return preparedExecutableURL
        }
        throw FixtureFailure(
            description: "Compile Scripts/verify-xcresult-required-tests.swift to "
                + "\(preparedExecutableURL.path) before running this hosted suite."
        )
    }

    private static func prepareFixtureRunnerExecutable() throws -> URL? {
        let manager = FileManager.default
        if let injectedPath = ProcessInfo.processInfo.environment[
            "XCRESULT_FIXTURE_RUNNER_TEST_EXECUTABLE"
        ] {
            guard manager.isExecutableFile(atPath: injectedPath) else {
                throw FixtureFailure(
                    description: "XCRESULT_FIXTURE_RUNNER_TEST_EXECUTABLE is not executable."
                )
            }
            return URL(fileURLWithPath: injectedPath)
        }

        if let preparedRoot = Bundle.main.object(
            forInfoDictionaryKey: "XCResultVerifierRoot"
        ) as? String {
            let preparedExecutableURL = URL(fileURLWithPath: preparedRoot)
                .appendingPathComponent("fixture-runner")
            guard manager.isExecutableFile(atPath: preparedExecutableURL.path) else {
                throw FixtureFailure(
                    description: "The per-run fixture runner is not executable."
                )
            }
            return preparedExecutableURL
        }

        let preparedExecutableURL = manager.temporaryDirectory
            .appendingPathComponent("AppTemplate-XCResultRequiredTestsVerifier")
            .appendingPathComponent("fixture-runner")
        if manager.isExecutableFile(atPath: preparedExecutableURL.path) {
            return preparedExecutableURL
        }
        guard !manager.temporaryDirectory.path.contains("/Library/Containers/") else {
            throw FixtureFailure(
                description: "Compile Scripts/xcresult-required-tests-fixture-runner.swift to "
                    + "\(preparedExecutableURL.path) before running this hosted suite."
            )
        }
        return nil
    }

    private static let fixtureRunner = #"""
    #!/bin/sh
    set -eu
    test "$#" -eq 7
    test "$1" = "xcresulttool"
    test "$2" = "get"
    test "$3" = "test-results"
    test "$5" = "--path"
    test "$6" = "$XCRESULT_FIXTURE_RESULT"
    test "$7" = "--compact"
    test "$XCRESULT_FIXTURE_EXIT" -eq 0 || exit "$XCRESULT_FIXTURE_EXIT"
    case "$4" in
      summary) exec /bin/cat "$XCRESULT_FIXTURE_SUMMARY" ;;
      tests) exec /bin/cat "$XCRESULT_FIXTURE_TESTS" ;;
      *) exit 64 ;;
    esac
    """#

    private static func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) throws -> Outcome {
        let manager = FileManager.default
        let captureRoot = manager.temporaryDirectory
            .appendingPathComponent("XCResultRequiredTestsVerifierProcess-\(UUID().uuidString)")
        try manager.createDirectory(at: captureRoot, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: captureRoot) }

        let standardOutputURL = captureRoot.appendingPathComponent("stdout")
        let standardErrorURL = captureRoot.appendingPathComponent("stderr")
        guard manager.createFile(atPath: standardOutputURL.path, contents: nil),
              manager.createFile(atPath: standardErrorURL.path, contents: nil) else {
            throw FixtureFailure(description: "Could not create process capture files.")
        }
        let standardOutput = try FileHandle(forWritingTo: standardOutputURL)
        let standardError = try FileHandle(forWritingTo: standardErrorURL)
        defer {
            try? standardOutput.close()
            try? standardError.close()
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }
        try process.run()

        let deadline = DispatchTime.now() + timeout
        guard completion.wait(timeout: deadline) == .success else {
            let launchedPID = process.processIdentifier
            process.terminate()
            if completion.wait(timeout: .now() + 1) == .timedOut {
                _ = kill(launchedPID, SIGKILL)
                guard completion.wait(timeout: .now() + 2) == .success else {
                    throw FixtureFailure(
                        description: "Process \(launchedPID) did not terminate after timeout."
                    )
                }
            }
            throw FixtureFailure(
                description: "Process \(launchedPID) timed out after \(timeout) seconds."
            )
        }

        try standardOutput.close()
        try standardError.close()
        return Outcome(
            status: process.terminationStatus,
            standardOutput: String(
                decoding: try Data(contentsOf: standardOutputURL),
                as: UTF8.self
            ),
            standardError: String(
                decoding: try Data(contentsOf: standardErrorURL),
                as: UTF8.self
            )
        )
    }
}
#endif
