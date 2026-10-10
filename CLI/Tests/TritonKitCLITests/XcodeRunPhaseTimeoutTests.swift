import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Xcode run Simulator phase timeout")
struct XcodeRunPhaseTimeoutTests {
    @Test("explicit timeout reaches install and launch while nil retains legacy defaults", arguments: [Optional<Double>.none, Optional<Double>.some(600)])
    func phaseTimeout(timeout: Double?) throws {
        let simulator = "60667794-96F8-40E6-8664-85538EC4663E"
        let invocation = ResolvedXcodeInvocation(
            workspace: "/fixture/App.xcworkspace", project: nil, package: nil, scheme: "App", configuration: "Debug",
            sdk: "iphonesimulator", destination: "platform=iOS Simulator,id=\(simulator)",
            derivedDataPath: "/fixture/DerivedData", buildSettings: [], derivedDataCache: makeXcodeDerivedDataCacheInfo(path: "/fixture/DerivedData"), simulatorUDID: simulator, device: nil
        )
        var captured: [TKHostCommand] = []
        let result = try runXcodeBuildInstallLaunch(
            invocation: invocation, launchEnvironment: ["COMPAT_TEST": "fixture-value"], launchArguments: ["--fixture"], jsonl: false, timeout: timeout,
            simulatorBuild: { _, _, suppliedTimeout in
                #expect(suppliedTimeout == timeout)
                return TKXcodeActionSummary(
                    ok: true, action: "xcode.build", workspace: invocation.workspace, project: nil,
                    scheme: "App", configuration: "Debug", sdk: invocation.sdk, destination: invocation.destination,
                    derivedDataPath: invocation.derivedDataPath, durationMs: 1, sourceCommand: "xcodebuild build", exitCode: 0,
                    stdoutTruncated: false, stderrTruncated: false
                )
            },
            simulatorProduct: { _, suppliedTimeout, _, _ in
                #expect(suppliedTimeout == timeout)
                return TKXcodeBuiltAppProduct(target: "App", appPath: "/fixture/App.app", bundleID: "fixture.app")
            },
            simulatorHostCommand: { command, _, _ in
                captured.append(command)
                return (HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0), 1)
            }
        )
        #expect(result.ok)
        #expect(captured.count == 2)
        let legacy = [TKSimctlCommand.installApp(udid: simulator, appPath: "/fixture/App.app"), TKSimctlCommand.launchApp(udid: simulator, bundleID: "fixture.app", environment: ["COMPAT_TEST": "fixture-value"], arguments: ["--fixture"])]
        for (actual, original) in zip(captured, legacy) {
            #expect(actual == original.withTimeout(timeout))
        }
    }
}
