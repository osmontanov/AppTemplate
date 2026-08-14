#!/usr/bin/swift

import Foundation

private struct VerificationFailure: Error {
    let message: String
}

private struct Options {
    let resultURL: URL
    let requiredURL: URL
    let platform: String
    let rejectAnySkips: Bool

    static func parse(_ arguments: [String]) throws -> Self {
        var result: String?
        var required: String?
        var platform: String?
        var rejectAnySkips = false
        var index = 0

        func value(after option: String) throws -> String {
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw VerificationFailure(message: "Missing value for \(option).")
            }
            let value = arguments[valueIndex]
            guard !value.isEmpty, !value.hasPrefix("--") else {
                throw VerificationFailure(message: "Missing value for \(option).")
            }
            return value
        }

        while index < arguments.count {
            switch arguments[index] {
            case "--result":
                guard result == nil else {
                    throw VerificationFailure(message: "Duplicate --result option.")
                }
                result = try value(after: "--result")
                index += 2
            case "--required":
                guard required == nil else {
                    throw VerificationFailure(message: "Duplicate --required option.")
                }
                required = try value(after: "--required")
                index += 2
            case "--platform":
                guard platform == nil else {
                    throw VerificationFailure(message: "Duplicate --platform option.")
                }
                platform = try value(after: "--platform")
                index += 2
            case "--reject-any-skips":
                guard !rejectAnySkips else {
                    throw VerificationFailure(message: "Duplicate --reject-any-skips option.")
                }
                rejectAnySkips = true
                index += 1
            default:
                throw VerificationFailure(message: "Unknown option \(arguments[index]).")
            }
        }

        guard let result, let required, let platform else {
            throw VerificationFailure(
                message: "Usage: verify-xcresult-required-tests.swift --result <bundle> --required <manifest.tsv> --platform <macos|iphone|ipad> [--reject-any-skips]"
            )
        }
        guard ["macos", "iphone", "ipad"].contains(platform) else {
            throw VerificationFailure(message: "Unknown platform \(platform).")
        }

        return Self(
            resultURL: URL(fileURLWithPath: result),
            requiredURL: URL(fileURLWithPath: required),
            platform: platform,
            rejectAnySkips: rejectAnySkips
        )
    }
}

private struct Summary: Decodable {
    let result: String
    let totalTestCount: Int
    let passedTests: Int
    let failedTests: Int
    let skippedTests: Int
}

private struct TestTree: Decodable {
    let testNodes: [TestNode]
}

private struct TestNode: Decodable {
    let nodeType: String
    let nodeIdentifier: String?
    let result: String?
    let children: [TestNode]?
}

private enum TestStatus: String {
    case passed = "Passed"
    case failed = "Failed"
    case skipped = "Skipped"
}

private struct ResultTest {
    let identifier: String
    let status: TestStatus
}

private struct Requirement {
    let platform: String
    let identifier: String
    let allowsSkip: Bool
}

private struct CommandRunner {
    let executableURL: URL

    static var live: Self {
        let environment = ProcessInfo.processInfo.environment
        return Self(
            executableURL: URL(
                fileURLWithPath: environment["XCRESULT_REQUIRED_TESTS_RUNNER"]
                    ?? "/usr/bin/xcrun"
            )
        )
    }

    func xcresulttool(_ operation: String, resultURL: URL) throws -> Data {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "xcresulttool", "get", "test-results", operation,
            "--path", resultURL.path, "--compact"
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            throw VerificationFailure(message: "xcresulttool command failed to launch.")
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw VerificationFailure(
                message: "xcresulttool command failed for \(operation) with exit \(process.terminationStatus)."
            )
        }
        guard !data.isEmpty else {
            throw VerificationFailure(message: "xcresulttool returned empty \(operation) JSON.")
        }
        return data
    }
}

private func decodeSummary(_ data: Data) throws -> Summary {
    do {
        return try JSONDecoder().decode(Summary.self, from: data)
    } catch {
        throw VerificationFailure(message: "Malformed summary JSON or schema.")
    }
}

private func decodeTests(_ data: Data) throws -> TestTree {
    do {
        return try JSONDecoder().decode(TestTree.self, from: data)
    } catch {
        throw VerificationFailure(message: "Malformed tests JSON or schema.")
    }
}

private func collectTests(from nodes: [TestNode]) throws -> [ResultTest] {
    var tests: [ResultTest] = []

    func visit(_ node: TestNode) throws {
        if node.nodeType == "Test Case" {
            guard let identifier = node.nodeIdentifier, !identifier.isEmpty,
                  let rawStatus = node.result, let status = TestStatus(rawValue: rawStatus) else {
                if let rawStatus = node.result, TestStatus(rawValue: rawStatus) == nil {
                    throw VerificationFailure(message: "Unknown test status \(rawStatus).")
                }
                throw VerificationFailure(message: "Malformed Test Case node schema.")
            }
            tests.append(ResultTest(identifier: identifier, status: status))
        }
        for child in node.children ?? [] {
            try visit(child)
        }
    }

    for node in nodes {
        try visit(node)
    }
    return tests
}

private func loadRequirements(from url: URL) throws -> [Requirement] {
    let source: String
    do {
        source = try String(contentsOf: url, encoding: .utf8)
    } catch {
        throw VerificationFailure(message: "Could not read required-tests manifest.")
    }

    var requirements: [Requirement] = []
    var seenRows: Set<String> = []
    for (offset, originalLine) in source.components(separatedBy: "\n").enumerated() {
        let line = originalLine.hasSuffix("\r") ? String(originalLine.dropLast()) : originalLine
        if line.isEmpty || line.hasPrefix("#") { continue }
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        if fields == ["platform", "identifier"]
            || fields == ["platform", "identifier", "skip"] {
            continue
        }
        guard fields.count == 2 || fields.count == 3 else {
            throw VerificationFailure(message: "Malformed manifest row \(offset + 1).")
        }
        let rowPlatform = fields[0]
        let identifier = fields[1]
        guard ["all", "macos", "iphone", "ipad"].contains(rowPlatform),
              !identifier.isEmpty,
              identifier == identifier.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw VerificationFailure(message: "Malformed manifest row \(offset + 1).")
        }
        let allowsSkip: Bool
        if fields.count == 3 {
            guard fields[2] == "allow-skip" else {
                throw VerificationFailure(message: "Malformed manifest row \(offset + 1).")
            }
            allowsSkip = true
        } else {
            allowsSkip = false
        }

        let rowKey = "\(rowPlatform)\u{0}\(identifier)"
        guard seenRows.insert(rowKey).inserted else {
            throw VerificationFailure(message: "Duplicate manifest row for \(identifier).")
        }
        requirements.append(
            Requirement(platform: rowPlatform, identifier: identifier, allowsSkip: allowsSkip)
        )
    }
    return requirements
}

private func verify(options: Options, runner: CommandRunner) throws -> Int {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(
        atPath: options.resultURL.path,
        isDirectory: &isDirectory
    ), isDirectory.boolValue, options.resultURL.pathExtension == "xcresult" else {
        throw VerificationFailure(message: "Result bundle does not exist or is not an .xcresult directory.")
    }

    let requirements = try loadRequirements(from: options.requiredURL)
    let selected = requirements.filter {
        $0.platform == "all" || $0.platform == options.platform
    }
    guard !selected.isEmpty else {
        throw VerificationFailure(message: "Manifest has no requirements for \(options.platform).")
    }
    var selectedByIdentifier: [String: Requirement] = [:]
    for requirement in selected {
        guard selectedByIdentifier.updateValue(requirement, forKey: requirement.identifier) == nil else {
            throw VerificationFailure(
                message: "Duplicate required identifier \(requirement.identifier)."
            )
        }
    }

    let summary = try decodeSummary(
        runner.xcresulttool("summary", resultURL: options.resultURL)
    )
    let tree = try decodeTests(
        runner.xcresulttool("tests", resultURL: options.resultURL)
    )
    let tests = try collectTests(from: tree.testNodes)

    var resultByIdentifier: [String: ResultTest] = [:]
    for test in tests {
        guard resultByIdentifier.updateValue(test, forKey: test.identifier) == nil else {
            throw VerificationFailure(message: "Duplicate result identifier \(test.identifier).")
        }
    }

    if let failed = tests.first(where: { $0.status == .failed }) {
        throw VerificationFailure(message: "Failed test \(failed.identifier).")
    }
    for skipped in tests where skipped.status == .skipped {
        let isAllowed = !options.rejectAnySkips
            && selectedByIdentifier[skipped.identifier]?.allowsSkip == true
        guard isAllowed else {
            throw VerificationFailure(message: "Skipped test \(skipped.identifier).")
        }
    }

    guard summary.result == "Passed" else {
        if summary.result == "Failed" {
            throw VerificationFailure(message: "Summary result is Failed.")
        }
        throw VerificationFailure(message: "Unknown summary status \(summary.result).")
    }
    guard summary.totalTestCount >= 0,
          summary.passedTests >= 0,
          summary.failedTests >= 0,
          summary.skippedTests >= 0,
          summary.totalTestCount
            == summary.passedTests + summary.failedTests + summary.skippedTests else {
        throw VerificationFailure(message: "Summary count mismatch.")
    }
    let passedCount = tests.filter { $0.status == .passed }.count
    let failedCount = tests.filter { $0.status == .failed }.count
    let skippedCount = tests.filter { $0.status == .skipped }.count
    guard tests.count == summary.totalTestCount,
          passedCount == summary.passedTests,
          failedCount == summary.failedTests,
          skippedCount == summary.skippedTests else {
        throw VerificationFailure(message: "Summary/result count mismatch.")
    }

    for requirement in selected {
        guard let result = resultByIdentifier[requirement.identifier] else {
            throw VerificationFailure(message: "Missing required test \(requirement.identifier).")
        }
        if result.status == .skipped,
           !options.rejectAnySkips,
           requirement.allowsSkip {
            continue
        }
        guard result.status == .passed else {
            throw VerificationFailure(
                message: "Required test \(requirement.identifier) was \(result.status.rawValue)."
            )
        }
    }
    return selected.count
}

do {
    let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
    let count = try verify(options: options, runner: .live)
    let noun = count == 1 ? "test" : "tests"
    print("Verified \(count) required \(noun) for \(options.platform).")
} catch let failure as VerificationFailure {
    FileHandle.standardError.write(Data("error: \(failure.message)\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("error: Verification failed closed.\n".utf8))
    exit(1)
}
