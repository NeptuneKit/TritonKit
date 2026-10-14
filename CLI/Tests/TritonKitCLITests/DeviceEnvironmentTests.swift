import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Device environment contracts")
struct DeviceEnvironmentTests {
    func target(_ scope: String = "emulator", platform: String = "android") -> HostDeviceTarget {
        HostDeviceTarget(platform: platform, id: "android:emulator-5554", target: "emulator-5554", state: "device", ready: true, source: "fixture", name: nil, runtime: nil, transport: nil, scope: scope)
    }
    func result(_ command: TKHostCommand, _ text: String) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(text.utf8), stderrData: Data(), exitCode: 0, sourceCommand: hostSourceCommand(command), stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: text.utf8.count, stderrBytes: 0)
    }
    @Test func commandParsingAndInvalidValues() throws {
        _ = try DeviceOrientation.parseAsRoot(["set", "landscape-left", "--device", "android:fixture"])
        _ = try DeviceFold.parseAsRoot(["half-open", "--angle", "90", "--device", "android:fixture"])
        #expect(throws: (any Error).self) { _ = try DeviceOrientation.parseAsRoot(["set", "sideways", "--device", "fixture"]) }
        #expect(throws: (any Error).self) { _ = try DeviceFold.parseAsRoot(["open", "--angle", "181", "--device", "fixture"]) }
        #expect(throws: (any Error).self) { _ = try DeviceLocation.parseAsRoot(["set", "91,0", "--device", "fixture"]) }
    }
    @Test func foregroundUsesResumedActivityOnly() {
        #expect(parseAndroidForeground("mResumedActivity: ActivityRecord{aa u0 com.example/.Main t9}") == "com.example")
        #expect(parseAndroidForeground("mCurrentFocus=Window{aa u0 com.stale/.Dialog}") == nil)
        #expect(parseAndroidForeground("topResumedActivity=ActivityRecord{aa u0 com.example/.Main t9}") == "com.example")
    }
    @Test func rotationsDoNotTreatStoredUserPreferenceAsDisplay() {
        #expect(parseAndroidDisplayRotation("mRotation=ROTATION_90") == 1)
        #expect(parseAndroidDisplayRotation("SurfaceOrientation: 3") == 3)
        #expect(parseAndroidDisplayRotation("user_rotation=1") == nil)
    }
    @Test func androidArgumentsEscapeRemoteShell() {
        let command = environmentADB(target: target(), adb: "adb", shell: ["cmd", "clipboard", "set", "a';$(touch /oops)\n你好"])
        #expect(command.arguments.count == 4)
        #expect(command.arguments[3].contains("'"))
        #expect(command.arguments[3].contains("'\\''"))
    }
    @Test func orientationPreservesBeforeAndVerifiesReadback() throws {
        var commands: [TKHostCommand] = []
        var rotationQueries = 0
        let output = try makeDeviceEnvironmentOutput(target: target("real"), operation: .orientationSet, value: "landscape-left", runner: { command in
            commands.append(command)
            if command.arguments.last?.contains("dumpsys") == true { rotationQueries += 1; return result(command, "mRotation=ROTATION_\(rotationQueries == 1 ? 0 : 90)") }
            if command.arguments.last?.contains("settings get") == true { return result(command, "0\n") }
            return result(command, "")
        })
        #expect(output.ok && output.executed && output.verified)
        #expect(output.previous?["orientation"] == "portrait")
        #expect(output.observed?["orientation"] == "landscape-left")
        #expect(commands.filter { $0.riskLevel != .readonly }.count == 3)
    }
    @Test func physicalFoldCannotReachEmulatorConsole() throws {
        let output = try makeDeviceEnvironmentOutput(target: target("real"), operation: .fold, value: "open", runner: { command in Issue.record("Physical device must not call console"); return result(command, "") })
        #expect(!output.ok && !output.supported && !output.executed)
        #expect(output.error?.code == "unsupported_device_environment")
    }
    @Test func emulatorConsoleKOIsFailureEvenWithExitZero() throws {
        let output = try makeDeviceEnvironmentOutput(target: target(), operation: .fold, value: "open", runner: { command in result(command, "KO: Device is not foldable\n") })
        #expect(!output.ok && !output.supported && !output.verified)
    }
    @Test func gpsOrderingIsLongitudeThenLatitude() {
        let command = environmentGeoFix(target: target(), latitude: 37.5, longitude: -122.25, adb: "adb")
        #expect(command.arguments == ["-s", "emulator-5554", "emu", "geo", "fix", "-122.25", "37.5"])
    }
    @Test func clipboardSourceNeverContainsText() {
        let command = environmentClipboardCommand(target: target(), adb: "adb", operation: "set", text: "SECRET")
        #expect(!hostSourceCommand(command).contains("SECRET"))
        #expect(command.stdinData == Data("SECRET".utf8))
        #expect(command.sensitiveOutput)
    }
}
