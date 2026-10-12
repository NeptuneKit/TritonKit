import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct XcodePackageArtifactTests {
    @Test("package output paths preserve defaults, nil and absolute paths")
    func pathVariants() throws {
        let package = "packages/Example"
        let base = URL(fileURLWithPath: package).standardizedFileURL
        #expect(xcodePackageArtifactPath(nil, package: package) == nil)
        #expect(xcodePackageArtifactPath("", package: package) == "")
        #expect(xcodePackageArtifactPath("a/../Tests.xcresult", package: package) == base.appendingPathComponent("Tests.xcresult").path)
        #expect(xcodePackageArtifactPath("/tmp/Tests.xcresult", package: package) == "/tmp/Tests.xcresult")
        #expect(xcodePackageArtifactPath("Tests.xcresult", package: nil) == "Tests.xcresult")
        let invocation = try resolveXcodeInvocation(package: package, scheme: "Example", sdk: "iphonesimulator", destination: "generic/platform=iOS Simulator")
        #expect(invocation.derivedDataPath == base.appendingPathComponent(".triton/DerivedData").path)
        #expect(invocation.derivedDataCache.path == invocation.derivedDataPath)
    }

    @Test("package test execution and inline parser read the same generated bundle")
    func generatedBundleIsReadFromExecutionDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("triton-result-\(UUID())")
        let package = root.appendingPathComponent("packages/Example With Space")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let resultPath = package.appendingPathComponent(".triton/Tests.xcresult").path
        let derivedData = package.appendingPathComponent(".triton/DerivedData").path
        let invocation = try resolveXcodeInvocation(
            package: package.appendingPathComponent("Package.swift").path,
            scheme: "Example", sdk: "iphonesimulator",
            destination: "generic/platform=iOS Simulator", derivedDataPath: ".triton/DerivedData"
        )
        #expect(invocation.derivedDataPath == derivedData)
        #expect(invocation.derivedDataCache.path == derivedData)
        var parsedPaths: [String] = []
        func result(_ command: TKHostCommand, _ text: String) -> HostProcessResult {
            let data = Data(text.utf8)
            return HostProcessResult(stdoutData: data, stderrData: Data(), exitCode: 0,
                sourceCommand: hostSourceCommand(command), stdoutTruncated: false, stderrTruncated: false,
                stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: data.count, stderrBytes: 0)
        }
        let summary = try runXcodeTest(
            invocation: invocation, resultBundlePath: ".triton/Tests.xcresult", jsonl: false,
            hostCommandRunner: { command, _, _, _ in
                #expect(command.workingDirectory == package.path)
                let index = try #require(command.arguments.firstIndex(of: "-resultBundlePath"))
                #expect(command.arguments[index + 1] == resultPath)
                let cacheIndex = try #require(command.arguments.firstIndex(of: "-derivedDataPath"))
                #expect(command.arguments[cacheIndex + 1] == derivedData)
                try FileManager.default.createDirectory(atPath: command.arguments[index + 1], withIntermediateDirectories: true)
                return (result(command, "** TEST SUCCEEDED **"), 1)
            }, resultCommandRunner: { command in
                let index = try #require(command.arguments.firstIndex(of: "--path"))
                let path = command.arguments[index + 1]
                #expect(path == resultPath)
                #expect(FileManager.default.fileExists(atPath: path))
                parsedPaths.append(path)
                let text = command.arguments.contains("summary")
                    ? "{\"title\":\"Example\",\"environmentDescription\":\"Fixture\",\"topInsights\":[],\"statistics\":[],\"result\":\"Passed\",\"totalTestCount\":1,\"passedTests\":1,\"failedTests\":0,\"skippedTests\":0,\"expectedFailures\":0}"
                    : "{\"testNodes\":[],\"testPlanConfigurations\":[],\"devices\":[]}"
                return result(command, text)
            }
        )
        #expect(parsedPaths == [resultPath, resultPath])
        #expect(summary.ok && summary.exitCode == 0)
        #expect(summary.resultBundlePath == resultPath)
        #expect(summary.testResultSummary?.passedTests == 1)
        #expect(summary.xcresultNote == nil)
    }
}
