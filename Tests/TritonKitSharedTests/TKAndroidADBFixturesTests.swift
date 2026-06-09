import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKAndroidADBFixturesTests {
    @Test("fake adb runner replays version stdout fixture")
    func fakeADBVersionFixture() throws {
        let runner = TKAndroidADBFakeRunner(fixtures: [.version])
        let result = try runner.run(TKAndroidADBCommand.version())
        let version = try TKAndroidADBVersionParser.parse(result.stdoutString)

        #expect(result.fixtureName == "adb-version")
        #expect(result.exitCode == 0)
        #expect(version.androidDebugBridgeVersion == "1.0.41")
        #expect(version.version == "35.0.2-12147458")
        #expect(version.installedAs == "/opt/android-sdk/platform-tools/adb")
    }

    @Test("fake adb runner replays device list matrix")
    func fakeADBDeviceListFixtures() throws {
        let empty = try TKAndroidADBFakeRunner(fixtures: [.devicesEmpty]).run(TKAndroidADBCommand.listDevices())
        #expect(TKAdbDeviceListParser.parse(empty.stdoutString).isEmpty)

        let singleReady = try TKAndroidADBFakeRunner(fixtures: [.devicesSingleReady]).run(TKAndroidADBCommand.listDevices())
        #expect(TKAdbDeviceListParser.defaultTarget(from: TKAdbDeviceListParser.parse(singleReady.stdoutString))?.serial == "emulator-5554")

        let multiReady = try TKAndroidADBFakeRunner(fixtures: [.devicesMultipleReady]).run(TKAndroidADBCommand.listDevices())
        #expect(TKAdbDeviceListParser.defaultTarget(from: TKAdbDeviceListParser.parse(multiReady.stdoutString)) == nil)

        let mixed = try TKAndroidADBFakeRunner(fixtures: [.devicesMixedStates]).run(TKAndroidADBCommand.listDevices())
        let targets = TKAdbDeviceListParser.parse(mixed.stdoutString)
        #expect(targets.map(\.state) == ["device", "offline", "unauthorized"])
        #expect(targets.filter(\.isReady).map(\.serial) == ["emulator-5554"])
    }

    @Test("fake adb runner replays boot completed ready false true and error")
    func fakeADBBootCompletedFixtures() throws {
        let falseResult = try TKAndroidADBFakeRunner(fixtures: [.bootCompletedFalse(serial: "emulator-5554")])
            .run(TKAndroidADBCommand.bootCompleted(serial: "emulator-5554"))
        #expect(TKAndroidBootCompletedParser.parse(falseResult.stdoutString, stderr: falseResult.stderrString, exitCode: falseResult.exitCode) == .notReady)

        let trueResult = try TKAndroidADBFakeRunner(fixtures: [.bootCompletedTrue(serial: "emulator-5554")])
            .run(TKAndroidADBCommand.bootCompleted(serial: "emulator-5554"))
        #expect(TKAndroidBootCompletedParser.parse(trueResult.stdoutString, stderr: trueResult.stderrString, exitCode: trueResult.exitCode) == .ready)

        let errorResult = try TKAndroidADBFakeRunner(fixtures: [.bootCompletedError(serial: "emulator-5554")])
            .run(TKAndroidADBCommand.bootCompleted(serial: "emulator-5554"))
        #expect(TKAndroidBootCompletedParser.parse(errorResult.stdoutString, stderr: errorResult.stderrString, exitCode: errorResult.exitCode) == .failed("device offline"))
    }

    @Test("fake adb runner replays screenshot success and failure")
    func fakeADBScreenshotFixtures() throws {
        let success = try TKAndroidADBFakeRunner(fixtures: [.screenshotPNG(serial: "emulator-5554")])
            .run(TKAndroidADBCommand.screenshot(serial: "emulator-5554"))
        #expect(TKAndroidScreenshotParser.parse(stdout: success.stdout, stderr: success.stderrString, exitCode: success.exitCode).ok)
        #expect(success.stdout.starts(with: Data([0x89, 0x50, 0x4E, 0x47])))

        let failure = try TKAndroidADBFakeRunner(fixtures: [.screenshotFailure(serial: "emulator-5554")])
            .run(TKAndroidADBCommand.screenshot(serial: "emulator-5554"))
        let parsed = TKAndroidScreenshotParser.parse(stdout: failure.stdout, stderr: failure.stderrString, exitCode: failure.exitCode)
        #expect(!parsed.ok)
        #expect(parsed.error == "screencap failed")
    }

    @Test("fake adb runner replays install launch and uiautomator dump")
    func fakeADBAppAndLayoutFixtures() throws {
        let runner = TKAndroidADBFakeRunner(fixtures: [
            .installSuccess(serial: "emulator-5554", apkPath: "/tmp/Demo.apk"),
            .dumpsysPackageSuccess(serial: "emulator-5554", packageName: "com.example.demo"),
            .resolveActivitySuccess(serial: "emulator-5554", packageName: "com.example.demo", component: "com.example.demo/.MainActivity"),
            .amStartSuccess(serial: "emulator-5554", component: "com.example.demo/.MainActivity"),
            .uiautomatorDump(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml"),
            .readFileXML(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml"),
        ])

        let install = try runner.run(TKAndroidADBCommand.installAPK(serial: "emulator-5554", apkPath: "/tmp/Demo.apk"))
        #expect(TKAndroidInstallParser.parse(install.stdoutString, stderr: install.stderrString, exitCode: install.exitCode).ok)

        let package = try runner.run(TKAndroidADBCommand.dumpsysPackage(serial: "emulator-5554", packageName: "com.example.demo"))
        let app = TKAndroidPackageInfoParser.parse(package.stdoutString, packageName: "com.example.demo")
        #expect(app.version == "1.2.3")
        #expect(app.path == "/data/app/~~hash/com.example.demo-base")

        let resolve = try runner.run(TKAndroidADBCommand.resolveActivity(serial: "emulator-5554", packageName: "com.example.demo"))
        let resolved = TKAndroidResolveActivityParser.parse(resolve.stdoutString, stderr: resolve.stderrString, exitCode: resolve.exitCode)
        #expect(resolved.ok)
        #expect(resolved.component == "com.example.demo/.MainActivity")

        let start = try runner.run(TKAndroidADBCommand.launch(serial: "emulator-5554", component: "com.example.demo/.MainActivity"))
        let startStatus = TKAndroidActivityStartParser.parse(start.stdoutString, stderr: start.stderrString, exitCode: start.exitCode)
        #expect(startStatus.ok)
        #expect(startStatus.component == "com.example.demo/.MainActivity")

        let dump = try runner.run(TKAndroidADBCommand.uiautomatorDump(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml"))
        #expect(try TKAndroidUIAutomatorDumpParser.remotePath(from: dump.stdoutString) == "/sdcard/window_dump.xml")

        let xml = try runner.run(TKAndroidADBCommand.readFile(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml"))
        let nodes = try TKAndroidUIAutomatorXMLParser.nodeSummaries(in: xml.stdout)
        #expect(nodes.count == 2)
        #expect(nodes[1].text == "Login")
        #expect(nodes[1].bounds == TKRect(x: 24, y: 120, width: 192, height: 72))
    }

    @Test("android package info parser supports app inspect compatibility")
    func androidPackageInfoParserSupportsAppInspectCompatibility() throws {
        let stdout = """
        Package [com.example.demo] (123abc):
          codePath=/data/app/~~hash/com.example.demo-base
          resourcePath=/data/app/~~hash/com.example.demo-base/base.apk
          versionName=1.2.3
          dataDir=/data/user/0/com.example.demo
        """
        let app = TKAndroidPackageInfoParser.parse(stdout, packageName: "com.example.demo")

        #expect(app.bundleID == "com.example.demo")
        #expect(app.applicationType == "Android")
        #expect(app.version == "1.2.3")
        #expect(app.path == "/data/app/~~hash/com.example.demo-base")
        #expect(app.bundleURL == "/data/app/~~hash/com.example.demo-base/base.apk")
        #expect(app.dataContainerURL == "/data/user/0/com.example.demo")
    }
}
