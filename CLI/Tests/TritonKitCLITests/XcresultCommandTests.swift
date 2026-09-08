import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcresultCommandTests {
    @Test("xcode test result details inline top failures from xcresult")
    func xcodeTestResultDetailsInlineTopFailures() throws {
        let details = xcodeTestResultBundleDetails(resultBundlePath: "/tmp/App.xcresult", maximumFailures: 1) { command in
            if command.arguments.contains("summary") {
                return hostProcessResult(stdout: validSummaryJSON)
            }
            return hostProcessResult(stdout: validTestsJSON)
        }

        #expect(details.summary?.failedTests == 1)
        #expect(details.topFailures?.map(\.testName) == ["testLogin()"])
        #expect(details.topFailures?.first?.message.contains("XCTAssertEqual failed") == true)
        #expect(details.note == nil)
    }

    @Test("inline result bounds long failure messages and summary text")
    func inlineResultBoundsLongText() throws {
        let longText = String(repeating: "failure detail ", count: 20_000)
        let details = xcodeTestResultBundleDetails(resultBundlePath: "/tmp/App.xcresult") { command in
            if command.arguments.contains("summary") {
                let statistics = (0..<100).map { _ in ["title": String(repeating: "stat ", count: 400), "subtitle": "value"] }
                var summary = try #require(JSONSerialization.jsonObject(with: Data(validSummaryJSON.utf8)) as? [String: Any])
                summary["environmentDescription"] = longText
                summary["statistics"] = statistics
                return hostProcessResult(stdout: String(decoding: try JSONSerialization.data(withJSONObject: summary), as: UTF8.self))
            }
            return hostProcessResult(stdout: validTestsJSON.replacingOccurrences(of: "XCTAssertEqual failed: 1 is not equal to 2", with: longText))
        }
        #expect(details.summary?.totalTestCount == 3)
        #expect(details.summary?.failedTests == 1)
        #expect(details.summary?.status == "failed")
        #expect(details.summary?.result == "Failed")
        #expect(try #require(details.summary?.statistics).count <= 8)
        #expect(try #require(details.summary?.environmentDescription).utf8.count < 2100)
        #expect(try #require(details.topFailures?.first?.message).utf8.count < 2100)
        #expect(details.note?.contains("truncated") == true)
    }

    @Test("xcresult summary output maps invalid JSON to parse failed")
    func summaryOutputMapsInvalidJSONToParseFailed() throws {
        let result = hostProcessResult(stdout: #"{"unexpected":true}"#)

        do {
            _ = try makeHostXcresultSummaryOutput(path: "/tmp/App.xcresult", includeSensitive: false, result: result)
            Issue.record("Expected xcresult summary parsing to fail")
        } catch XcresultCLIError.parseFailed(let kind, _) {
            #expect(kind == "summary")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("xcresult failures output maps invalid tests JSON to parse failed")
    func failuresOutputMapsInvalidTestsJSONToParseFailed() throws {
        let summary = hostProcessResult(stdout: validSummaryJSON)
        let tests = hostProcessResult(stdout: #"{"unexpected":true}"#)

        do {
            _ = try makeHostXcresultFailuresOutput(path: "/tmp/App.xcresult", includeSensitive: false, summaryResult: summary, testsResult: tests)
            Issue.record("Expected xcresult tests parsing to fail")
        } catch XcresultCLIError.parseFailed(let kind, _) {
            #expect(kind == "tests")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("xcresult failures accepts Xcode 26.6 summary device arrays")
    func failuresOutputAcceptsXcode266SummaryDeviceArrays() throws {
        let summary = hostProcessResult(stdout: validArraySummaryJSON)
        let tests = hostProcessResult(stdout: validTestsJSON)

        let output = try makeHostXcresultFailuresOutput(
            path: "/tmp/App.xcresult",
            includeSensitive: false,
            summaryResult: summary,
            testsResult: tests
        )

        #expect(output.ok)
        #expect(output.action == "xcresult.failures")
        #expect(output.summary.devicesAndConfigurations?.device.deviceName == "Test Mac")
        #expect(output.summary.testFailure?.testIdentifierString == "case-1")
        #expect(output.failures.map(\.testName) == ["testLogin()"])
    }

    private func hostProcessResult(stdout: String) -> HostProcessResult {
        let stdoutData = Data(stdout.utf8)
        return HostProcessResult(
            stdoutData: stdoutData,
            stderrData: Data(),
            exitCode: 0,
            sourceCommand: "xcrun xcresulttool get test-results --compact",
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: stdoutData.count,
            stderrBytes: 0
        )
    }
}

private let validSummaryJSON = """
{
  "title": "AppTests",
  "startTime": 10.0,
  "finishTime": 12.5,
  "environmentDescription": "iPhone 17, iOS 26.5",
  "topInsights": [],
  "result": "Failed",
  "totalTestCount": 3,
  "passedTests": 2,
  "failedTests": 1,
  "skippedTests": 0,
  "expectedFailures": 0,
  "statistics": []
}
"""

private let validArraySummaryJSON = #"{"title":"AppTests","startTime":10,"finishTime":12.5,"environmentDescription":"macOS 26.4","topInsights":[],"result":"Failed","totalTestCount":3,"passedTests":2,"failedTests":1,"skippedTests":0,"expectedFailures":0,"statistics":[],"devicesAndConfigurations":[{"device":{"deviceId":"DEVICE-1","deviceName":"Test Mac","architecture":"arm64","modelName":"Mac","platform":"macOS","osVersion":"26.4","osBuildNumber":"25E"},"testPlanConfiguration":{"configurationId":"cfg-1","configurationName":"Test Scheme Action"},"passedTests":2,"failedTests":1,"skippedTests":0,"expectedFailures":0}],"testFailures":[{"testName":"AppTests/testFailure()","targetName":"AppTests","failureText":"Expected true","testIdentifierString":"case-1"}]}"#

private let validTestsJSON = """
{
  "testPlanConfigurations": [],
  "devices": [],
  "testNodes": [
    {
      "nodeIdentifier": "bundle-1",
      "nodeIdentifierURL": "xcresult://bundle/1",
      "nodeType": "Unit test bundle",
      "name": "AppTests",
      "children": [
        {
          "nodeIdentifier": "suite-1",
          "nodeIdentifierURL": "xcresult://suite/1",
          "nodeType": "Test Suite",
          "name": "AppTests",
          "children": [
            {
              "nodeIdentifier": "case-1",
              "nodeIdentifierURL": "xcresult://case/1",
              "nodeType": "Test Case",
              "name": "testLogin()",
              "children": [
                {
                  "nodeIdentifier": "run-1",
                  "nodeIdentifierURL": "xcresult://run/1",
                  "nodeType": "Test Case Run",
                  "name": "testLogin()",
                  "result": "Failed",
                  "children": [
                    {
                      "nodeIdentifier": "failure-1",
                      "nodeType": "Failure Message",
                      "name": "XCTAssertEqual failed",
                      "details": "XCTAssertEqual failed: 1 is not equal to 2"
                    },
                    {
                      "nodeIdentifier": "source-1",
                      "nodeType": "Source Code Reference",
                      "name": "Tests/AppTests.swift:42",
                      "details": "Tests/AppTests.swift:42"
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
"""
