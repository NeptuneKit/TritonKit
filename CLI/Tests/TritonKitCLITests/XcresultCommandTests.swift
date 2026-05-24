import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct XcresultCommandTests {
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
