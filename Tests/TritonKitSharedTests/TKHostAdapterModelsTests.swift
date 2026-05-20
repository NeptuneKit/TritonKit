import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKHostAdapterModelsTests {
    @Test("workspace defaults path is repo local and stable")
    func workspaceDefaultsPath() throws {
        let defaults = TKHostWorkspaceDefaults(defaultSimulatorUDID: "U")
        let data = try JSONEncoder().encode(defaults)
        let decoded = try JSONDecoder().decode(TKHostWorkspaceDefaults.self, from: data)

        #expect(decoded.defaultSimulatorUDID == "U")
        #expect(TKHostWorkspaceDefaults.filePath(workspace: "/tmp/project") == "/tmp/project/.triton/host-defaults.json")
    }

    @Test("simctl command builder emits stable P0 argv")
    func simctlCommandBuilderP0Argv() {
        #expect(TKSimctlCommand.listAvailableDevices().argv == ["simctl", "list", "devices", "available", "--json"])
        #expect(TKSimctlCommand.boot(udid: "U").argv == ["simctl", "boot", "U"])
        #expect(TKSimctlCommand.shutdown(udid: "U").argv == ["simctl", "shutdown", "U"])
        #expect(TKSimctlCommand.screenshot(udid: "U", output: "/tmp/shot.png").argv == ["simctl", "io", "U", "screenshot", "/tmp/shot.png"])
        #expect(TKSimctlCommand.listApps(udid: "U").argv == ["simctl", "listapps", "U"])
        #expect(TKSimctlCommand.appInfo(udid: "U", bundleID: "com.example.app").argv == ["simctl", "appinfo", "U", "com.example.app"])
        #expect(TKSimctlCommand.installApp(udid: "U", appPath: "/tmp/Demo.app").argv == ["simctl", "install", "U", "/tmp/Demo.app"])
        #expect(TKSimctlCommand.launchApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "launch", "U", "com.example.app"])
        #expect(TKSimctlCommand.terminateApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "terminate", "U", "com.example.app"])
        #expect(TKSimctlCommand.openURL(udid: "U", url: "example://debug").argv == ["simctl", "openurl", "U", "example://debug"])
        #expect(TKSimctlCommand.appContainer(udid: "U", bundleID: "com.example.app", kind: .data).argv == ["simctl", "get_app_container", "U", "com.example.app", "data"])
    }

    @Test("host commands expose risk and objective runtime config instead of confirmation gates")
    func hostCommandsExposeRiskAndRuntimeConfig() {
        #expect(TKSimctlCommand.boot(udid: "U").riskLevel == .automation)
        #expect(TKSimctlCommand.erase(udid: "U").riskLevel == .breakGlass)
        #expect(TKSimctlCommand.uninstallApp(udid: "U", bundleID: "com.example.app").riskLevel == .automation)
        #expect(TKSimctlCommand.installAppData(udid: "U", xcappdata: "/tmp/state.xcappdata").requiredConfig.contains(.auditRecord))
        #expect(TKSimctlCommand.screenshot(udid: "U", output: "/tmp/shot.png").requiredConfig == [.artifactDir, .redactionPolicy, .timeout, .auditRecord])
        #expect(TKSimctlCommand.erase(udid: "U").argv == ["simctl", "erase", "U"])
    }

    @Test("host execution policy resolves from explicit value before environment and default")
    func hostExecutionPolicyResolution() {
        let explicit = TKHostExecutionPolicy.resolve(
            explicitMode: .automation,
            artifactDir: "/tmp/artifacts",
            redactionPolicy: "summary",
            timeoutSeconds: 20,
            environment: ["TRITON_HOST_POLICY": "readonly"]
        )
        #expect(explicit.mode == .automation)
        #expect(explicit.artifactDir == "/tmp/artifacts")
        #expect(explicit.redactionPolicy == "summary")
        #expect(explicit.timeoutSeconds == 20)

        let harmonyEnvironment = TKHostExecutionPolicy.resolve(
            environment: ["HARMONY_NEXT_AUTOMATION_POLICY": "diagnostic"]
        )
        #expect(harmonyEnvironment.mode == .diagnostic)

        let fallback = TKHostExecutionPolicy.resolve(environment: [:])
        #expect(fallback.mode == .readonly)
    }

    @Test("host command validation blocks only objectively missing runtime config")
    func hostCommandValidationReportsMissingRuntimeConfig() {
        let command = TKHostCommand(
            executable: "hdc",
            arguments: ["-t", "127.0.0.1:10100", "shell", "uitest", "screenCap"],
            riskLevel: .evidence,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            capturesArtifacts: true,
            sensitiveOutput: true
        )
        let policy = TKHostExecutionPolicy(mode: .evidence, target: "127.0.0.1:10100", timeoutSeconds: 5)

        let blocked = command.missingRequiredConfig(policy: policy)

        #expect(blocked == [.artifactDir, .redactionPolicy, .auditRecord])
    }

    @Test("Harmony HDC command builder emits argv without shell string concatenation")
    func harmonyHDCCommandBuilderArgv() {
        #expect(TKHarmonyHDCCommand.listTargets(executable: "/tmp/hdc").executable == "/tmp/hdc")
        #expect(TKHarmonyHDCCommand.version().argv == ["-v"])
        #expect(TKHarmonyHDCCommand.listTargets().argv == ["list", "targets", "-v"])
        #expect(TKHarmonyHDCCommand.bootCompleted(target: "127.0.0.1:10100").argv == ["-t", "127.0.0.1:10100", "shell", "param", "get", "bootevent.boot.completed"])
        #expect(TKHarmonyHDCCommand.appInspect(target: "127.0.0.1:10100", bundleName: "com.example.demo").argv == ["-t", "127.0.0.1:10100", "shell", "bm", "dump", "-n", "com.example.demo"])
        #expect(TKHarmonyHDCCommand.appLaunch(target: "127.0.0.1:10100", bundleName: "com.example.demo", abilityName: "EntryAbility").argv == ["-t", "127.0.0.1:10100", "shell", "aa", "start", "-b", "com.example.demo", "-a", "EntryAbility"])
        #expect(TKHarmonyHDCCommand.inputText(target: "127.0.0.1:10100", text: "hello world").argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "text", "hello world"])
    }

    @Test("HDC target parser preserves offline entries and default candidates only connected targets")
    func hdcTargetParser() throws {
        let output = """
        127.0.0.1:10100    Connected
        127.0.0.1:10200    Offline
        FMR0224C03001399    Connected
        """

        let targets = TKHdcTargetListParser.parse(output)

        #expect(targets.map(\.id) == ["harmony:127.0.0.1:10100", "harmony:127.0.0.1:10200", "harmony:FMR0224C03001399"])
        #expect(targets.map(\.state) == ["Connected", "Offline", "Connected"])
        #expect(targets.filter(\.isConnected).map(\.target) == ["127.0.0.1:10100", "FMR0224C03001399"])
        #expect(TKHdcTargetListParser.defaultTarget(from: targets) == nil)
    }

    @Test("HDC target parser handles verbose transport state columns")
    func hdcVerboseTargetParser() throws {
        let output = """
        127.0.0.1:10100        TCP     Connected       localhost
        127.0.0.1:10200        TCP     Offline         localhost
        """

        let targets = TKHdcTargetListParser.parse(output)

        #expect(targets.map(\.target) == ["127.0.0.1:10100", "127.0.0.1:10200"])
        #expect(targets.map(\.transport) == ["TCP", "TCP"])
        #expect(targets.map(\.state) == ["Connected", "Offline"])
        #expect(targets.filter(\.isConnected).map(\.target) == ["127.0.0.1:10100"])
        #expect(TKHdcTargetListParser.defaultTarget(from: targets)?.target == "127.0.0.1:10100")
    }

    @Test("Harmony boot parser only treats true as ready")
    func harmonyBootCompletedParser() {
        #expect(TKHarmonyBootCompletedParser.isReady("true\n"))
        #expect(!TKHarmonyBootCompletedParser.isReady("false\n"))
        #expect(!TKHarmonyBootCompletedParser.isReady("1\n"))
        #expect(!TKHarmonyBootCompletedParser.isReady(""))
    }

    @Test("simctl devices JSON decodes into simulator targets")
    func simctlDeviceListDecoding() throws {
        let json = """
        {
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
              {
                "lastBootedAt": "2026-05-20T09:00:00Z",
                "dataPath": "/tmp/device",
                "logPath": "/tmp/logs",
                "udid": "0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
                "isAvailable": true,
                "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17",
                "state": "Booted",
                "name": "TritonKit Dedicated iPhone 17 Simulator"
              }
            ],
            "com.apple.CoreSimulator.SimRuntime.watchOS-26-5": []
          }
        }
        """

        let targets = try TKSimctlDeviceListParser.parse(Data(json.utf8))

        let target = try #require(targets.first)
        #expect(target.id == "sim:0333546D-2AC6-4C22-AF01-293E2F4BA5BC")
        #expect(target.udid == "0333546D-2AC6-4C22-AF01-293E2F4BA5BC")
        #expect(target.name == "TritonKit Dedicated iPhone 17 Simulator")
        #expect(target.runtimeIdentifier == "com.apple.CoreSimulator.SimRuntime.iOS-26-5")
        #expect(target.platform == "iOS Simulator")
        #expect(target.runtime == "iOS 26.5")
        #expect(target.state == "Booted")
        #expect(target.isBooted)
        #expect(target.source == "simctl")
    }

    @Test("simctl listapps openstep plist decodes into installed app summaries")
    func simctlListAppsDecoding() throws {
        let plist = """
        {
            "com.example.demo" = {
                ApplicationType = User;
                CFBundleDisplayName = Demo;
                CFBundleExecutable = Demo;
                CFBundleIdentifier = "com.example.demo";
                CFBundleName = Demo;
                CFBundleVersion = 42;
                DataContainer = "file:///tmp/Data/";
                GroupContainers = {
                    "group.com.example.demo" = "file:///tmp/Group/";
                };
                Path = "/tmp/Demo.app";
                SBAppTags = (
                    "debuggable"
                );
            };
            "com.apple.Preferences" = {
                ApplicationType = System;
                CFBundleDisplayName = Settings;
                CFBundleIdentifier = "com.apple.Preferences";
                CFBundleVersion = "1.0";
                Path = "/Applications/Preferences.app";
            };
        }
        """

        let apps = try TKSimctlAppInfoParser.parseList(Data(plist.utf8))

        #expect(apps.map(\.bundleID) == ["com.apple.Preferences", "com.example.demo"])
        let demo = try #require(apps.first { $0.bundleID == "com.example.demo" })
        #expect(demo.displayName == "Demo")
        #expect(demo.executable == "Demo")
        #expect(demo.version == "42")
        #expect(demo.applicationType == "User")
        #expect(demo.path == "/tmp/Demo.app")
        #expect(demo.dataContainerURL == "file:///tmp/Data/")
        #expect(demo.groupContainers["group.com.example.demo"] == "file:///tmp/Group/")
        #expect(demo.tags == ["debuggable"])
    }

    @Test("simctl appinfo openstep plist decodes one installed app")
    func simctlAppInfoDecoding() throws {
        let plist = """
        {
            ApplicationType = User;
            CFBundleDisplayName = Demo;
            CFBundleIdentifier = "com.example.demo";
            CFBundleVersion = 42;
            Path = "/tmp/Demo.app";
        }
        """

        let app = try TKSimctlAppInfoParser.parseAppInfo(Data(plist.utf8), bundleID: "com.example.demo")

        #expect(app.bundleID == "com.example.demo")
        #expect(app.displayName == "Demo")
        #expect(app.version == "42")
        #expect(app.applicationType == "User")
    }

    @Test("empty simctl appinfo output is treated as not available")
    func emptySimctlAppInfoDecodingFails() throws {
        let plist = """
        {
            CFBundleIdentifier = "com.example.missing";
        }
        """

        #expect(throws: TKSimctlAppInfoParserError.emptyInfo) {
            _ = try TKSimctlAppInfoParser.parseAppInfo(Data(plist.utf8), bundleID: "com.example.missing")
        }
    }

    @Test("host app preferences decode property list values")
    func preferencePlistDecoding() throws {
        let plist: [String: Any] = [
            "DEBUG-mock": false,
            "ApplicationEnvironmentKey": 3,
            "Name": "Demo",
            "Nested": ["enabled": true],
            "List": ["a", "b"],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)

        let snapshot = try TKHostPreferencesSnapshot(bundleID: "com.example.app", plistPath: "/tmp/com.example.app.plist", data: data)

        #expect(snapshot.value(forKey: "DEBUG-mock") == .bool(false))
        #expect(snapshot.value(forKey: "ApplicationEnvironmentKey") == .int(3))
        #expect(snapshot.value(forKey: "Name") == .string("Demo"))
        #expect(snapshot.value(forKey: "Missing") == nil)
        #expect(snapshot.preferences["Nested"]?.kind == "dictionary")
        #expect(snapshot.preferences["List"]?.kind == "array")
    }

    @Test("preference plist path is derived from data container and bundle id")
    func preferencePathDerivation() {
        let path = TKHostPreferencesSnapshot.plistPath(dataContainer: "/tmp/AppData", bundleID: "com.example.app")

        #expect(path == "/tmp/AppData/Library/Preferences/com.example.app.plist")
    }
}
