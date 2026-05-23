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
        #expect(TKSimctlCommand.uninstallApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "uninstall", "U", "com.example.app"])
        #expect(TKSimctlCommand.launchApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "launch", "U", "com.example.app"])
        #expect(TKSimctlCommand.terminateApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "terminate", "U", "com.example.app"])
        #expect(TKSimctlCommand.openURL(udid: "U", url: "example://debug").argv == ["simctl", "openurl", "U", "example://debug"])
        #expect(TKSimctlCommand.appContainer(udid: "U", bundleID: "com.example.app", kind: .data).argv == ["simctl", "get_app_container", "U", "com.example.app", "data"])
    }

    @Test("simctl command builder emits advanced simulator maintenance argv")
    func simctlCommandBuilderAdvancedArgv() {
        #expect(TKSimctlCommand.diagnose(output: "/tmp/sim-diagnostics", timeout: 15, noArchive: true, allLogs: true, dataContainers: true, udids: ["U1", "U2"]).argv == ["simctl", "diagnose", "--timeout", "15.0", "--output", "/tmp/sim-diagnostics", "--no-archive", "--all-logs", "--data-containers", "--udid", "U1", "--udid", "U2"])
        #expect(TKSimctlCommand.recordVideo(udid: "U", output: "/tmp/sim.mov", codec: "hevc", display: "internal", mask: "black", force: true, defaultTimeoutSeconds: 90).argv == ["simctl", "io", "U", "recordVideo", "--codec=hevc", "--display=internal", "--mask=black", "--force", "/tmp/sim.mov"])
        #expect(TKSimctlCommand.logStream(udid: "U", duration: 5, style: "ndjson", level: "debug", predicate: "subsystem == \"com.example.app\"", source: true, type: "log").argv == ["simctl", "spawn", "U", "log", "stream", "--style", "ndjson", "--timeout", "5", "--level", "debug", "--predicate", "subsystem == \"com.example.app\"", "--source", "--type", "log"])
        #expect(TKSimctlCommand.logVerbose(udid: "U", enabled: true).argv == ["simctl", "logverbose", "U", "enable"])
        #expect(TKSimctlCommand.logVerbose(enabled: false).argv == ["simctl", "logverbose", "disable"])
        #expect(TKSimctlCommand.runtimeList().argv == ["simctl", "runtime", "list", "-j"])
        #expect(TKSimctlCommand.runtimeVerify(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5").argv == ["simctl", "runtime", "verify", "com.apple.CoreSimulator.SimRuntime.iOS-26-5"])
        #expect(TKSimctlCommand.statusBarList(udid: "U").argv == ["simctl", "status_bar", "U", "list"])
        #expect(TKSimctlCommand.statusBarClear(udid: "U").argv == ["simctl", "status_bar", "U", "clear"])
        #expect(TKSimctlCommand.statusBarOverride(udid: "U", time: "09:41", batteryLevel: 100).argv == ["simctl", "status_bar", "U", "override", "--time", "09:41", "--batteryLevel", "100"])
        #expect(TKSimctlCommand.privacy(udid: "U", action: "grant", service: "location", bundleID: "com.example.app").argv == ["simctl", "privacy", "U", "grant", "location", "com.example.app"])
        #expect(TKSimctlCommand.locationList(udid: "U").argv == ["simctl", "location", "U", "list"])
        #expect(TKSimctlCommand.locationClear(udid: "U").argv == ["simctl", "location", "U", "clear"])
        #expect(TKSimctlCommand.locationSet(udid: "U", coordinate: "37.7749,-122.4194").argv == ["simctl", "location", "U", "set", "37.7749,-122.4194"])
        #expect(TKSimctlCommand.locationRun(udid: "U", scenario: "city-run").argv == ["simctl", "location", "U", "run", "city-run"])
        #expect(TKSimctlCommand.locationStart(udid: "U", waypoints: ["37.629538,-122.395733", "40.628083,-73.768254"], speed: 260, distance: 1000).argv == ["simctl", "location", "U", "start", "--speed=260.0", "--distance=1000.0", "37.629538,-122.395733", "40.628083,-73.768254"])
        #expect(TKSimctlCommand.uiAppearance(udid: "U").argv == ["simctl", "ui", "U", "appearance"])
        #expect(TKSimctlCommand.uiAppearance(udid: "U", value: "dark").argv == ["simctl", "ui", "U", "appearance", "dark"])
        #expect(TKSimctlCommand.uiIncreaseContrast(udid: "U").argv == ["simctl", "ui", "U", "increase_contrast"])
        #expect(TKSimctlCommand.uiIncreaseContrast(udid: "U", value: "enabled").argv == ["simctl", "ui", "U", "increase_contrast", "enabled"])
        #expect(TKSimctlCommand.uiContentSize(udid: "U").argv == ["simctl", "ui", "U", "content_size"])
        #expect(TKSimctlCommand.uiContentSize(udid: "U", value: "accessibility-large").argv == ["simctl", "ui", "U", "content_size", "accessibility-large"])
        #expect(TKSimctlCommand.pasteboardCopy(udid: "U", text: "hello").argv == ["simctl", "pbcopy", "U"])
        #expect(TKSimctlCommand.pasteboardPaste(udid: "U").argv == ["simctl", "pbpaste", "U"])
        #expect(TKSimctlCommand.pasteboardSync(source: "host", destination: "U").argv == ["simctl", "pbsync", "host", "U"])
        #expect(TKSimctlCommand.push(udid: "U", bundleID: "com.example.app", payload: "/tmp/push.json").argv == ["simctl", "push", "U", "com.example.app", "/tmp/push.json"])
    }

    @Test("simctl command builder emits phase three simulator maintenance argv")
    func simctlCommandBuilderPhaseThreeArgv() {
        #expect(TKSimctlCommand.pair(watchDevice: "WATCH", phoneDevice: "PHONE").argv == ["simctl", "pair", "WATCH", "PHONE"])
        #expect(TKSimctlCommand.unpair(pairUUID: "PAIR").argv == ["simctl", "unpair", "PAIR"])
        #expect(TKSimctlCommand.clone(device: "U", newName: "Clone").argv == ["simctl", "clone", "U", "Clone"])
        #expect(TKSimctlCommand.clone(device: "U", newName: "Clone", destinationDeviceSet: "/tmp/deviceset").argv == ["simctl", "clone", "U", "Clone", "/tmp/deviceset"])
        #expect(TKSimctlCommand.upgrade(device: "U", runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5").argv == ["simctl", "upgrade", "U", "com.apple.CoreSimulator.SimRuntime.iOS-26-5"])
        #expect(TKSimctlCommand.runtimeAdd(path: "/tmp/iOS.dmg", move: true, async: true).argv == ["simctl", "runtime", "add", "/tmp/iOS.dmg", "--move", "--async"])
        #expect(TKSimctlCommand.runtimeDelete(identifier: "RUNTIME", dryRun: true, keepAsset: true).argv == ["simctl", "runtime", "delete", "RUNTIME", "--dry-run", "--keep-asset"])
        #expect(TKSimctlCommand.runtimeDelete(notUsedSinceDays: 30, dryRun: true, keepAsset: true).argv == ["simctl", "runtime", "delete", "--notUsedSinceDays", "30", "--dry-run", "--keep-asset"])
        #expect(TKSimctlCommand.runtimeUnmount(identifier: "RUNTIME").argv == ["simctl", "runtime", "unmount", "RUNTIME"])
        #expect(TKSimctlCommand.runtimeScanAndMount().argv == ["simctl", "runtime", "scan-and-mount"])
        #expect(TKSimctlCommand.runtimeMatchList(verbose: true).argv == ["simctl", "runtime", "match", "list", "-v", "-j"])
        #expect(TKSimctlCommand.runtimeMatchSet(sdkName: "iphonesimulator26.0", runtimeBuild: "23F77", sdkBuild: "23F66").argv == ["simctl", "runtime", "match", "set", "iphonesimulator26.0", "23F77", "--sdkBuild", "23F66"])
        #expect(TKSimctlCommand.runtimeMatchSetDefault(sdkName: "iphonesimulator26.0", sdkBuild: "23F66").argv == ["simctl", "runtime", "match", "set", "iphonesimulator26.0", "--default", "--sdkBuild", "23F66"])
        #expect(TKSimctlCommand.runtimeDyldSharedCacheUpdate(runtime: "RUNTIME", force: true).argv == ["simctl", "runtime", "dyld_shared_cache", "update", "RUNTIME", "--force"])
        #expect(TKSimctlCommand.runtimeDyldSharedCacheUpdate(all: true).argv == ["simctl", "runtime", "dyld_shared_cache", "update", "--all"])
        #expect(TKSimctlCommand.runtimeDyldSharedCacheRemove(all: true).argv == ["simctl", "runtime", "dyld_shared_cache", "remove", "--all"])
        #expect(TKSimctlCommand.personalization(action: "personalize", arguments: ["RUNTIME"]).argv == ["simctl", "personalization", "personalize", "RUNTIME"])
        #expect(TKSimctlCommand.personalization(action: "remove-all-manifests", riskLevel: .breakGlass).argv == ["simctl", "personalization", "remove-all-manifests"])
    }

    @Test("simctl runtime JSON decodes into runtime summaries")
    func simctlRuntimeListDecoding() throws {
        let json = """
        {
          "67DA9196-7AB6-49E0-80F1-1C9C1D0C90B5" : {
            "build" : "23F77",
            "deletable" : true,
            "identifier" : "67DA9196-7AB6-49E0-80F1-1C9C1D0C90B5",
            "kind" : "Patchable Cryptex Disk Image",
            "lastUsedAt" : "2026-05-22T15:40:45Z",
            "mountPath" : "/Library/Developer/CoreSimulator/Volumes/iOS_23F77",
            "parentMountPath" : "/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/af14d04fa4f5b29c2471951b01491c6403eab68f.asset/AssetData",
            "path" : "/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/af14d04fa4f5b29c2471951b01491c6403eab68f.asset/AssetData/Restore/iOSSimulatorRuntime_Cryptex.dmg",
            "platformIdentifier" : "com.apple.platform.iphonesimulator",
            "runtimeBundlePath" : "/Library/Developer/CoreSimulator/Volumes/iOS_23F77/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.5.simruntime",
            "runtimeIdentifier" : "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
            "signatureState" : "Verified",
            "sizeBytes" : 10597197700,
            "state" : "Ready",
            "supportedArchitectures" : [
              "x86_64",
              "arm64"
            ],
            "version" : "26.5"
          }
        }
        """

        let runtimes = try TKSimctlRuntimeListParser.parse(Data(json.utf8))
        let runtime = try #require(runtimes.first)

        #expect(runtimes.count == 1)
        #expect(runtime.id == "runtime:67DA9196-7AB6-49E0-80F1-1C9C1D0C90B5")
        #expect(runtime.identifier == "67DA9196-7AB6-49E0-80F1-1C9C1D0C90B5")
        #expect(runtime.runtimeIdentifier == "com.apple.CoreSimulator.SimRuntime.iOS-26-5")
        #expect(runtime.platformIdentifier == "com.apple.platform.iphonesimulator")
        #expect(runtime.version == "26.5")
        #expect(runtime.kind == "Patchable Cryptex Disk Image")
        #expect(runtime.supportedArchitectures == ["x86_64", "arm64"])
        #expect(runtime.source == "simctl")
    }

    @Test("host commands expose risk and objective runtime config instead of confirmation gates")
    func hostCommandsExposeRiskAndRuntimeConfig() {
        #expect(TKSimctlCommand.boot(udid: "U").riskLevel == .automation)
        #expect(TKSimctlCommand.erase(udid: "U").riskLevel == .breakGlass)
        #expect(TKSimctlCommand.runtimeDelete(identifier: "RUNTIME").riskLevel == .breakGlass)
        #expect(TKSimctlCommand.runtimeDelete(identifier: "RUNTIME", dryRun: true).riskLevel == .readonly)
        #expect(TKSimctlCommand.personalization(action: "remove-all-manifests", riskLevel: .breakGlass).riskLevel == .breakGlass)
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
        #expect(TKHarmonyHDCCommand.forwardPort(target: "127.0.0.1:10100", localPort: 18765, remotePort: 18765).argv == ["-t", "127.0.0.1:10100", "fport", "tcp:18765", "tcp:18765"])
        #expect(TKHarmonyHDCCommand.inputText(target: "127.0.0.1:10100", text: "hello world").argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "text", "hello world"])
        #expect(TKHarmonyHDCCommand.installHap(target: "127.0.0.1:10100", hapPath: "/tmp/Demo.hap").argv == ["-t", "127.0.0.1:10100", "install", "-r", "/tmp/Demo.hap"])
        #expect(TKHarmonyHDCCommand.forceStop(target: "127.0.0.1:10100", bundleName: "com.example.demo").argv == ["-t", "127.0.0.1:10100", "shell", "aa", "force-stop", "com.example.demo"])
        #expect(TKHarmonyHDCCommand.appOpenURL(target: "127.0.0.1:10100", bundleName: "com.example.demo", abilityName: "EntryAbility", url: "demo://nativejump/index").argv == ["-t", "127.0.0.1:10100", "shell", "aa", "start", "-a", "EntryAbility", "-b", "com.example.demo", "-U", "demo://nativejump/index"])
        #expect(TKHarmonyHDCCommand.dumpLayout(target: "127.0.0.1:10100").argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "dumpLayout"])
        #expect(TKHarmonyHDCCommand.recvFile(target: "127.0.0.1:10100", remotePath: "/data/local/tmp/layout.json", localPath: "/tmp/layout.json").argv == ["-t", "127.0.0.1:10100", "file", "recv", "/data/local/tmp/layout.json", "/tmp/layout.json"])
        #expect(TKHarmonyHDCCommand.tapCoordinate(target: "127.0.0.1:10100", x: 120, y: 640).argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "click", "120", "640"])
        #expect(TKHarmonyHDCCommand.screenshot(target: "127.0.0.1:10100", remotePath: "/data/local/tmp/smoke.jpeg").argv == ["-t", "127.0.0.1:10100", "shell", "snapshot_display", "-f", "/data/local/tmp/smoke.jpeg"])
    }

    @Test("Harmony dumpLayout parser extracts remote file path")
    func harmonyDumpLayoutRemotePathParser() throws {
        let output = """
        some preface
        DumpLayout saved to:/data/local/tmp/layout_001.json
        """

        #expect(try TKHarmonyDumpLayoutParser.remotePath(from: output) == "/data/local/tmp/layout_001.json")
        #expect(throws: TKHarmonyDumpLayoutParserError.remotePathNotFound) {
            _ = try TKHarmonyDumpLayoutParser.remotePath(from: "No layout path")
        }
    }

    @Test("Harmony layout parser finds text node bounds center")
    func harmonyLayoutTextBoundsParser() throws {
        let layout = """
        {
          "attributes": { "text": "root", "bounds": "[0,0][390,844]" },
          "children": [
            {
              "attributes": {
                "text": "目标",
                "bounds": "[24,600][144,680]"
              }
            }
          ]
        }
        """

        let parsed = try TKHarmonyLayoutParser.firstTextMatch(in: Data(layout.utf8), text: "目标")
        let match = try #require(parsed)

        #expect(match.text == "目标")
        #expect(match.bounds == TKRect(x: 24, y: 600, width: 120, height: 80))
        #expect(match.centerX == 84)
        #expect(match.centerY == 640)
        let missing = try TKHarmonyLayoutParser.firstTextMatch(in: Data(layout.utf8), text: "missing")
        #expect(missing == nil)
    }

    @Test("Harmony layout parser flattens host nodes for observe and node resolve")
    func harmonyLayoutNodeSummaries() throws {
        let layout = """
        {
          "attributes": {
            "accessibilityId": "0",
            "hierarchy": "ROOT1",
            "type": "root",
            "text": "",
            "bounds": "[0,0][390,844]",
            "clickable": "false",
            "enabled": "true",
            "visible": "true"
          },
          "children": [
            {
              "attributes": {
                "accessibilityId": "10",
                "hierarchy": "ROOT1,0",
                "type": "Web",
                "text": "resource:/RAWFILE/index.html",
                "bounds": "[0,100][390,700]",
                "clickable": "false",
                "enabled": "true",
                "focused": "true",
                "scrollable": "false",
                "visible": "true"
              },
              "children": [
                {
                  "attributes": {
                    "accessibilityId": "11",
                    "hierarchy": "ROOT1,0,0",
                    "id": "loginBt",
                    "key": "loginBt",
                    "type": "button",
                    "text": "登录",
                    "bounds": "[24,600][144,680]",
                    "clickable": "true",
                    "enabled": "true",
                    "visible": "true"
                  },
                  "children": []
                }
              ]
            }
          ]
        }
        """

        let nodes = try TKHarmonyLayoutParser.nodeSummaries(in: Data(layout.utf8))

        #expect(nodes.count == 3)
        #expect(nodes.map(\.nodeID) == ["ROOT1", "ROOT1,0", "ROOT1,0,0"])
        let web = try #require(nodes.first { $0.type == "Web" })
        #expect(web.text == "resource:/RAWFILE/index.html")
        #expect(web.bounds == TKRect(x: 0, y: 100, width: 390, height: 600))
        #expect(web.focused == true)
        let login = try #require(nodes.first { $0.text == "登录" })
        #expect(login.identifier == "loginBt")
        #expect(login.key == "loginBt")
        #expect(login.clickable == true)
        #expect(login.depth == 2)
        #expect(login.bounds?.centerX == 84)
        #expect(login.bounds?.centerY == 640)
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

    @Test("embedded runtime HTTP routes map request model to Harmony SDK endpoints")
    func embeddedRuntimeHTTPRoutes() throws {
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .runtimeManifest) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/manifest"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .stateApp) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/app"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .stateScene) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/scene"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .stateRoute) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/route"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .stateResponder) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/responder"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .runtimeSnapshot) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/snapshot"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .runtimeLedger) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/ledger"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .semanticAction) == TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/action"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .hierarchy) == nil)
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
