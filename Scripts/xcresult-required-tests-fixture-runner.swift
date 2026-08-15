#!/usr/bin/swift

import Foundation

private func fail(_ code: Int32) -> Never {
    Foundation.exit(code)
}

let arguments = CommandLine.arguments
guard arguments.count == 8,
      arguments[1] == "xcresulttool",
      arguments[2] == "get",
      arguments[3] == "test-results",
      arguments[5] == "--path",
      arguments[7] == "--compact" else {
    fail(64)
}

let environment = ProcessInfo.processInfo.environment
guard let expectedResult = environment["XCRESULT_FIXTURE_RESULT"],
      arguments[6] == expectedResult,
      let rawExit = environment["XCRESULT_FIXTURE_EXIT"],
      let requestedExit = Int32(rawExit) else {
    fail(64)
}
guard requestedExit == 0 else {
    fail(requestedExit)
}

let fixtureVariable: String
switch arguments[4] {
case "summary":
    fixtureVariable = "XCRESULT_FIXTURE_SUMMARY"
case "tests":
    fixtureVariable = "XCRESULT_FIXTURE_TESTS"
default:
    fail(64)
}

guard let fixturePath = environment[fixtureVariable],
      let fixtureData = FileManager.default.contents(atPath: fixturePath) else {
    fail(66)
}
FileHandle.standardOutput.write(fixtureData)
