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
        #expect(TKSimctlCommand.screenshot(udid: "U", output: "/tmp/shot.png", display: "internal").argv == ["simctl", "io", "U", "screenshot", "--display=internal", "/tmp/shot.png"])
        #expect(TKSimctlCommand.listApps(udid: "U").argv == ["simctl", "listapps", "U"])
        #expect(TKSimctlCommand.appInfo(udid: "U", bundleID: "com.example.app").argv == ["simctl", "appinfo", "U", "com.example.app"])
        #expect(TKSimctlCommand.installApp(udid: "U", appPath: "/tmp/Demo.app").argv == ["simctl", "install", "U", "/tmp/Demo.app"])
        #expect(TKSimctlCommand.uninstallApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "uninstall", "U", "com.example.app"])
        #expect(TKSimctlCommand.launchApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "launch", "U", "com.example.app"])
        #expect(TKSimctlCommand.terminateApp(udid: "U", bundleID: "com.example.app").argv == ["simctl", "terminate", "U", "com.example.app"])
        #expect(TKSimctlCommand.openURL(udid: "U", url: "example://debug").argv == ["simctl", "openurl", "U", "example://debug"])
        #expect(TKSimctlCommand.appContainer(udid: "U", bundleID: "com.example.app", kind: .data).argv == ["simctl", "get_app_container", "U", "com.example.app", "data"])
    }

    @Test("devicectl command builder always writes JSON and log artifacts")
    func devicectlCommandBuilderArgv() {
        #expect(TKDevicectlCommand.listDevices(jsonOutput: "/tmp/list.json", logOutput: "/tmp/list.log").argv == ["devicectl", "list", "devices", "--json-output", "/tmp/list.json", "--log-output", "/tmp/list.log"])
        #expect(TKDevicectlCommand.deviceInfoDetails(identifier: "00008110", jsonOutput: "/tmp/details.json", logOutput: "/tmp/details.log").argv == ["devicectl", "device", "info", "details", "--device", "00008110", "--json-output", "/tmp/details.json", "--log-output", "/tmp/details.log"])
        #expect(TKDevicectlCommand.deviceInfoApps(identifier: "00008110", jsonOutput: "/tmp/apps.json", logOutput: "/tmp/apps.log").argv == ["devicectl", "device", "info", "apps", "--device", "00008110", "--json-output", "/tmp/apps.json", "--log-output", "/tmp/apps.log"])
        #expect(TKDevicectlCommand.installApp(identifier: "00008110", appPath: "/tmp/Demo.app", jsonOutput: "/tmp/install.json", logOutput: "/tmp/install.log").argv == ["devicectl", "device", "install", "app", "--device", "00008110", "/tmp/Demo.app", "--json-output", "/tmp/install.json", "--log-output", "/tmp/install.log"])
        #expect(TKDevicectlCommand.launchApp(identifier: "00008110", bundleID: "com.example.demo", payloadURL: "demo://ready", terminateExisting: true, jsonOutput: "/tmp/launch.json", logOutput: "/tmp/launch.log").argv == ["devicectl", "device", "process", "launch", "--device", "00008110", "--terminate-existing", "--payload-url", "demo://ready", "--json-output", "/tmp/launch.json", "--log-output", "/tmp/launch.log", "com.example.demo"])
        let launchWithEnv = TKDevicectlCommand.launchApp(
            identifier: "00008110",
            bundleID: "com.example.demo",
            environment: ["TRITON_HOST": "192.168.1.2", "TRITON_PORT": "19431"],
            arguments: ["debug-route"],
            jsonOutput: "/tmp/launch.json",
            logOutput: "/tmp/launch.log"
        )
        #expect(launchWithEnv.argv == [
            "devicectl", "device", "process", "launch",
            "--device", "00008110",
            "--environment-variables", "{\"TRITON_HOST\":\"192.168.1.2\",\"TRITON_PORT\":\"19431\"}",
            "--json-output", "/tmp/launch.json",
            "--log-output", "/tmp/launch.log",
            "com.example.demo", "debug-route",
        ])
        #expect(launchWithEnv.environment.isEmpty)
        #expect(launchWithEnv.redactedEnvironmentKeys.isEmpty)
        #expect(launchWithEnv.redactedArgumentIndexes == Set([7]))
        #expect(TKDevicectlCommand.copyFromDevice(
            identifier: "00008110",
            source: "Library/Application Support/bench/evidence.json",
            destination: "/tmp/evidence.json",
            domainType: .appDataContainer,
            domainIdentifier: "com.example.demo",
            jsonOutput: "/tmp/pull.json",
            logOutput: "/tmp/pull.log"
        ).argv == [
            "devicectl", "device", "copy", "from",
            "--device", "00008110",
            "--source", "Library/Application Support/bench/evidence.json",
            "--destination", "/tmp/evidence.json",
            "--domain-type", "appDataContainer",
            "--domain-identifier", "com.example.demo",
            "--json-output", "/tmp/pull.json",
            "--log-output", "/tmp/pull.log",
        ])
        #expect(TKDevicectlCommand.copyFromDevice(
            identifier: "00008110",
            source: "Shared/report.json",
            destination: "/tmp/group-report.json",
            domainType: .appGroupDataContainer,
            domainIdentifier: "group.com.example.demo",
            jsonOutput: "/tmp/group-pull.json",
            logOutput: "/tmp/group-pull.log"
        ).argv.contains("appGroupDataContainer"))
        #expect(TKDevicectlCommand.terminateApp(identifier: "00008110", bundleID: "com.example.demo", jsonOutput: "/tmp/terminate.json", logOutput: "/tmp/terminate.log").argv == ["devicectl", "device", "process", "terminate", "--device", "00008110", "com.example.demo", "--json-output", "/tmp/terminate.json", "--log-output", "/tmp/terminate.log"])
        #expect(TKDevicectlCommand.uninstallApp(identifier: "00008110", bundleID: "com.example.demo", jsonOutput: "/tmp/uninstall.json", logOutput: "/tmp/uninstall.log").argv == ["devicectl", "device", "uninstall", "app", "--device", "00008110", "com.example.demo", "--json-output", "/tmp/uninstall.json", "--log-output", "/tmp/uninstall.log"])
    }

    @Test("devicectl parser maps ready real device without leaking sensitive identifiers")
    func devicectlParserReadyDevice() throws {
        let devices = try TKDevicectlDeviceListParser.parse(Data(devicectlListJSON(device: """
        {
          "identifier": "00008110-001C195E0A10801E",
          "deviceProperties": {
            "name": "Lin iPhone",
            "osVersionNumber": "26.5",
            "developerModeStatus": "enabled",
            "ddiServicesAvailable": true,
            "lockState": "unlocked"
          },
          "hardwareProperties": {
            "udid": "00008110-001C195E0A10801E-UDID",
            "serialNumber": "F2LPRIVATE",
            "ecid": "1234567890"
          },
          "connectionProperties": {
            "transportType": "usb",
            "pairingState": "paired",
            "tunnelState": "connected"
          },
          "visibilityClass": "default"
        }
        """).utf8))
        let device = try #require(devices.first)

        #expect(device.platform == "ios")
        #expect(device.scope == "real")
        #expect(device.kind == "real-device")
        #expect(device.source == "devicectl")
        #expect(device.identifier == "00008110-001C195E0A10801E")
        #expect(device.alternateIdentifiers.contains("00008110-001C195E0A10801E-UDID"))
        #expect(device.id.hasPrefix("ios-real:"))
        #expect(device.redactedTarget == device.id)
        #expect(device.ready)
        #expect(device.blockedReasons == [])
        #expect(device.name == "Lin iPhone")
        #expect(device.runtime == "iOS 26.5")
        #expect(device.transport == "usb")
        #expect(device.id.contains("00008110") == false)

        let encoded = String(decoding: try JSONEncoder().encode(device), as: UTF8.self)
        #expect(!encoded.contains("alternateIdentifiers"))
        #expect(!encoded.contains("00008110-001C195E0A10801E-UDID"))
        #expect(!encoded.contains("F2LPRIVATE"))
    }

    @Test("devicectl parser maps blocked real-device fixtures")
    func devicectlParserBlockedDevices() throws {
        let devices = try TKDevicectlDeviceListParser.parse(Data("""
        {
          "info": { "outcome": "success" },
          "result": {
            "devices": [
              {
                "identifier": "OFFLINE-DEVICE",
                "deviceProperties": { "name": "Offline iPhone", "osVersionNumber": "26.5", "developerModeStatus": "enabled", "ddiServicesAvailable": true, "lockState": "unlocked" },
                "connectionProperties": { "transportType": "usb", "pairingState": "paired", "tunnelState": "disconnected" },
                "visibilityClass": "offline"
              },
              {
                "identifier": "UNTRUSTED-DEVICE",
                "deviceProperties": { "name": "Trust Prompt", "osVersionNumber": "26.5", "developerModeStatus": "enabled", "ddiServicesAvailable": true, "lockState": "unlocked" },
                "connectionProperties": { "transportType": "usb", "pairingState": "untrusted", "tunnelState": "connected" },
                "visibilityClass": "default"
              },
              {
                "identifier": "DEV-MODE-DEVICE",
                "deviceProperties": { "name": "Developer Mode", "osVersionNumber": "26.5", "developerModeStatus": "disabled", "ddiServicesAvailable": true, "lockState": "unlocked" },
                "connectionProperties": { "transportType": "usb", "pairingState": "paired", "tunnelState": "connected" },
                "visibilityClass": "default"
              },
              {
                "identifier": "LOCKED-DEVICE",
                "deviceProperties": { "name": "Locked", "osVersionNumber": "26.5", "developerModeStatus": "enabled", "ddiServicesAvailable": true, "lockState": "locked" },
                "connectionProperties": { "transportType": "usb", "pairingState": "paired", "tunnelState": "connected" },
                "visibilityClass": "default"
              },
              {
                "identifier": "DDI-DEVICE",
                "deviceProperties": { "name": "Missing DDI", "osVersionNumber": "26.5", "developerModeStatus": "enabled", "ddiServicesAvailable": false, "lockState": "unlocked" },
                "connectionProperties": { "transportType": "usb", "pairingState": "paired", "tunnelState": "connected" },
                "visibilityClass": "default"
              }
            ]
          }
        }
        """.utf8))

        #expect(devices.map(\.blockedReasons) == [["offline"], ["not-trusted"], ["developer-mode-required"], ["locked"], ["ddi-missing"]])
        #expect(devices.allSatisfy { !$0.ready })
    }

    @Test("devicectl parser rejects malformed JSON and missing device arrays")
    func devicectlParserRejectsMalformedFixtures() throws {
        #expect(throws: TKDevicectlParserError.self) {
            _ = try TKDevicectlDeviceListParser.parse(Data("{".utf8))
        }
        #expect(throws: TKDevicectlParserError.missingDevices) {
            _ = try TKDevicectlDeviceListParser.parse(Data(#"{ "info": { "outcome": "success" }, "result": {} }"#.utf8))
        }
    }

    @Test("simctl command builder emits advanced simulator maintenance argv")
    func simctlCommandBuilderAdvancedArgv() {
        #expect(TKSimctlCommand.diagnose(output: "/tmp/sim-diagnostics", timeout: 15, noArchive: true, allLogs: true, dataContainers: true, udids: ["U1", "U2"]).argv == ["simctl", "diagnose", "--timeout=15.0", "--output=/tmp/sim-diagnostics", "--no-archive", "--all-logs", "--data-container", "--udid=U1", "--udid=U2"])
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
        #expect(TKSimctlCommand.addMedia(udid: "U", files: ["/tmp/a.png", "/tmp/b.mov"]).argv == ["simctl", "addmedia", "U", "/tmp/a.png", "/tmp/b.mov"])
    }

    @Test("media seed manifest decodes fixture metadata and resolves relative files")
    func mediaSeedManifestDecodesFixtureMetadata() throws {
        let directory = URL(fileURLWithPath: "/fixtures/gallery", isDirectory: true)
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let manifest = try TKSimulatorMediaSeedManifest.parse(
            Data("""
            {
              "fixtureId": "onboarding-gallery",
              "metadata": { "locale": "en-US" },
              "files": [
                "photos/welcome.png",
                { "path": "videos/intro.mov", "kind": "video", "sha256": "abc123" }
              ]
            }
            """.utf8),
            manifestURL: manifestURL
        )

        #expect(manifest.fixtureId == "onboarding-gallery")
        #expect(manifest.metadata["locale"] == "en-US")
        #expect(manifest.resolvedFiles.map(\.path) == [
            "/fixtures/gallery/photos/welcome.png",
            "/fixtures/gallery/videos/intro.mov",
        ])
        #expect(manifest.resolvedFiles[0].kind == "image")
        #expect(manifest.resolvedFiles[1].kind == "video")
        #expect(manifest.resolvedFiles[1].sha256 == "abc123")
    }

    @Test("media seed manifest rejects missing fixture id or empty files")
    func mediaSeedManifestRejectsInvalidInput() throws {
        let manifestURL = URL(fileURLWithPath: "/fixtures/manifest.json")

        #expect(throws: TKSimulatorMediaSeedManifestError.self) {
            _ = try TKSimulatorMediaSeedManifest.parse(Data(#"{ "files": ["a.png"] }"#.utf8), manifestURL: manifestURL)
        }
        #expect(throws: TKSimulatorMediaSeedManifestError.self) {
            _ = try TKSimulatorMediaSeedManifest.parse(Data(#"{ "fixtureId": "empty", "files": [] }"#.utf8), manifestURL: manifestURL)
        }
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
        #expect(TKHarmonyHDCCommand.listTargetsPlain().argv == ["list", "targets"])
        #expect(TKHarmonyHDCCommand.bootCompleted(target: "127.0.0.1:10100").argv == ["-t", "127.0.0.1:10100", "shell", "param", "get", "bootevent.boot.completed"])
        #expect(TKHarmonyHDCCommand.shellProbe(target: "127.0.0.1:10100").argv == ["-t", "127.0.0.1:10100", "shell", "echo", "triton-shell-ready"])
        #expect(TKHarmonyHDCCommand.paramListRecursive(target: "127.0.0.1:10100", name: "proxy").argv == ["-t", "127.0.0.1:10100", "shell", "param", "ls", "-r", "proxy"])
        #expect(TKHarmonyHDCCommand.appInspect(target: "127.0.0.1:10100", bundleName: "com.example.demo").argv == ["-t", "127.0.0.1:10100", "shell", "bm", "dump", "-n", "com.example.demo"])
        #expect(TKHarmonyHDCCommand.foregroundApp(target: "127.0.0.1:10100").argv == ["-t", "127.0.0.1:10100", "shell", "aa", "dump", "-l"])
        #expect(TKHarmonyHDCCommand.appLaunch(target: "127.0.0.1:10100", bundleName: "com.example.demo", abilityName: "EntryAbility").argv == ["-t", "127.0.0.1:10100", "shell", "aa", "start", "-b", "com.example.demo", "-a", "EntryAbility"])
        #expect(TKHarmonyHDCCommand.forwardPort(target: "127.0.0.1:10100", localPort: 18765, remotePort: 18765).argv == ["-t", "127.0.0.1:10100", "fport", "tcp:18765", "tcp:18765"])
        #expect(TKHarmonyHDCCommand.inputText(target: "127.0.0.1:10100", text: "hello world").argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "text", "hello world"])
        #expect(TKHarmonyHDCCommand.inputTextAt(target: "127.0.0.1:10100", x: 10, y: 20, text: "hello world").argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "inputText", "10", "20", "hello world"])
        #expect(TKHarmonyHDCCommand.tapCoordinate(target: "127.0.0.1:10100", x: 10, y: 20).argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "click", "10", "20"])
        #expect(TKHarmonyHDCCommand.swipeCoordinate(target: "127.0.0.1:10100", startX: 10, startY: 20, endX: 100, endY: 200).argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "swipe", "10", "20", "100", "200"])
        #expect(TKHarmonyHDCCommand.swipeCoordinate(target: "127.0.0.1:10100", startX: 10, startY: 20, endX: 100, endY: 200, velocity: 900).argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "swipe", "10", "20", "100", "200", "900"])
        #expect(TKHarmonyHDCCommand.keyEvent(target: "127.0.0.1:10100", key: "Back").argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "keyEvent", "Back"])
        #expect(TKHarmonyHDCCommand.installHap(target: "127.0.0.1:10100", hapPath: "/tmp/Demo.hap").argv == ["-t", "127.0.0.1:10100", "install", "-r", "/tmp/Demo.hap"])
        #expect(TKHarmonyHDCCommand.forceStop(target: "127.0.0.1:10100", bundleName: "com.example.demo").argv == ["-t", "127.0.0.1:10100", "shell", "aa", "force-stop", "com.example.demo"])
        #expect(TKHarmonyHDCCommand.appOpenURL(target: "127.0.0.1:10100", bundleName: "com.example.demo", abilityName: "EntryAbility", url: "demo://nativejump/index").argv == ["-t", "127.0.0.1:10100", "shell", "aa", "start", "-a", "EntryAbility", "-b", "com.example.demo", "-U", "demo://nativejump/index"])
        #expect(TKHarmonyHDCCommand.dumpLayout(target: "127.0.0.1:10100").argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "dumpLayout"])
        #expect(TKHarmonyHDCCommand.recvFile(target: "127.0.0.1:10100", remotePath: "/data/local/tmp/layout.json", localPath: "/tmp/layout.json").argv == ["-t", "127.0.0.1:10100", "file", "recv", "/data/local/tmp/layout.json", "/tmp/layout.json"])
        #expect(TKHarmonyHDCCommand.tapCoordinate(target: "127.0.0.1:10100", x: 120, y: 640).argv == ["-t", "127.0.0.1:10100", "shell", "uitest", "uiInput", "click", "120", "640"])
        #expect(TKHarmonyHDCCommand.screenshot(target: "127.0.0.1:10100", remotePath: "/data/local/tmp/smoke.jpeg").argv == ["-t", "127.0.0.1:10100", "shell", "snapshot_display", "-f", "/data/local/tmp/smoke.jpeg"])
    }

    @Test("Android ADB command builder emits argv without shell string concatenation")
    func androidADBCommandBuilderArgv() {
        #expect(TKAndroidADBCommand.version(executable: "/tmp/adb").executable == "/tmp/adb")
        #expect(TKAndroidADBCommand.version().argv == ["version"])
        #expect(TKAndroidADBCommand.listDevices().argv == ["devices", "-l"])
        #expect(TKAndroidADBCommand.bootCompleted(serial: "emulator-5554").argv == ["-s", "emulator-5554", "shell", "getprop", "sys.boot_completed"])
        #expect(TKAndroidADBCommand.screenshot(serial: "emulator-5554").argv == ["-s", "emulator-5554", "exec-out", "screencap", "-p"])
        #expect(TKAndroidADBCommand.screenshotToFile(serial: "emulator-5554", remotePath: "/sdcard/triton.png").argv == ["-s", "emulator-5554", "shell", "screencap", "-p", "/sdcard/triton.png"])
        #expect(TKAndroidADBCommand.pullFile(serial: "emulator-5554", remotePath: "/sdcard/triton.png", localPath: "/tmp/triton.png").argv == ["-s", "emulator-5554", "pull", "/sdcard/triton.png", "/tmp/triton.png"])
        #expect(TKAndroidADBCommand.removeFile(serial: "emulator-5554", remotePath: "/sdcard/triton.png").argv == ["-s", "emulator-5554", "shell", "rm", "-f", "/sdcard/triton.png"])
        #expect(TKAndroidADBCommand.installAPK(serial: "emulator-5554", apkPath: "/tmp/Demo.apk").argv == ["-s", "emulator-5554", "install", "-r", "/tmp/Demo.apk"])
        #expect(TKAndroidADBCommand.uninstall(serial: "emulator-5554", packageName: "com.example.demo").argv == ["-s", "emulator-5554", "uninstall", "com.example.demo"])
        #expect(TKAndroidADBCommand.resolveActivity(serial: "emulator-5554", packageName: "com.example.demo").argv == ["-s", "emulator-5554", "shell", "cmd", "package", "resolve-activity", "--brief", "com.example.demo"])
        #expect(TKAndroidADBCommand.launch(serial: "emulator-5554", packageName: "com.example.demo", activity: ".MainActivity").argv == ["-s", "emulator-5554", "shell", "am", "start", "-n", "com.example.demo/.MainActivity"])
        #expect(TKAndroidADBCommand.readFile(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml").argv == ["-s", "emulator-5554", "shell", "cat", "/sdcard/window_dump.xml"])
        #expect(TKAndroidADBCommand.forceStop(serial: "emulator-5554", packageName: "com.example.demo").argv == ["-s", "emulator-5554", "shell", "am", "force-stop", "com.example.demo"])
        #expect(TKAndroidADBCommand.openURL(serial: "emulator-5554", url: "demo://home").argv == ["-s", "emulator-5554", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", "demo://home"])
        #expect(TKAndroidADBCommand.openURL(serial: "emulator-5554", url: "demo://home", packageName: "com.example.demo").argv == ["-s", "emulator-5554", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", "demo://home", "-p", "com.example.demo"])
        #expect(TKAndroidADBCommand.listPackages(serial: "emulator-5554", userOnly: true).argv == ["-s", "emulator-5554", "shell", "pm", "list", "packages", "-3"])
        #expect(TKAndroidADBCommand.dumpsysPackage(serial: "emulator-5554", packageName: "com.example.demo").argv == ["-s", "emulator-5554", "shell", "dumpsys", "package", "com.example.demo"])
        #expect(TKAndroidADBCommand.tapCoordinate(serial: "emulator-5554", x: 10, y: 20).argv == ["-s", "emulator-5554", "shell", "input", "tap", "10", "20"])
        #expect(TKAndroidADBCommand.swipeCoordinate(serial: "emulator-5554", startX: 10, startY: 20, endX: 100, endY: 200).argv == ["-s", "emulator-5554", "shell", "input", "swipe", "10", "20", "100", "200"])
        #expect(TKAndroidADBCommand.swipeCoordinate(serial: "emulator-5554", startX: 10, startY: 20, endX: 100, endY: 200, durationMs: 350).argv == ["-s", "emulator-5554", "shell", "input", "swipe", "10", "20", "100", "200", "350"])
        #expect(TKAndroidADBCommand.inputText(serial: "emulator-5554", text: "hello%sworld").argv == ["-s", "emulator-5554", "shell", "input", "text", "hello%sworld"])
        #expect(TKAndroidADBCommand.keyEvent(serial: "emulator-5554", keyCode: "KEYCODE_BACK").argv == ["-s", "emulator-5554", "shell", "input", "keyevent", "KEYCODE_BACK"])
        #expect(TKAndroidADBCommand.wmSize(serial: "emulator-5554").argv == ["-s", "emulator-5554", "shell", "wm", "size"])
    }

    @Test("Android package parsers map adb output into installed app summaries")
    func androidPackageParsers() {
        let listOutput = """
        package:com.android.settings
        package:com.example.demo
        """

        let apps = TKAndroidPackageListParser.parse(listOutput)
        #expect(apps.map(\.bundleID) == ["com.android.settings", "com.example.demo"])
        #expect(apps[0].applicationType == "Android")

        let infoOutput = """
        Package [com.example.demo] (abc):
          codePath=/data/app/~~hash/com.example.demo-base
          resourcePath=/data/app/~~hash/com.example.demo-base/base.apk
          versionName=1.2.3
          dataDir=/data/user/0/com.example.demo
        """
        let app = TKAndroidPackageInfoParser.parse(infoOutput, packageName: "com.example.demo")
        #expect(app.bundleID == "com.example.demo")
        #expect(app.version == "1.2.3")
        #expect(app.path == "/data/app/~~hash/com.example.demo-base")
        #expect(app.bundleURL == "/data/app/~~hash/com.example.demo-base/base.apk")
        #expect(app.dataContainerURL == "/data/user/0/com.example.demo")
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

        #expect(targets[0].id == "harmony:127.0.0.1:10100")
        #expect(targets[1].id == "harmony:127.0.0.1:10200")
        #expect(targets[2].id.hasPrefix("harmony-real:"))
        #expect(targets[2].id.contains("FMR0224C03001399") == false)
        #expect(targets.map(\.state) == ["Connected", "Offline", "Connected"])
        #expect(targets.map(\.scope) == [.emulator, .emulator, .real])
        #expect(targets.map(\.kind) == ["emulator", "emulator", "real-device"])
        #expect(targets.map(\.blockedReasons) == [[], ["offline"], []])
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

    @Test("HDC target parser handles plain single-column output and ignores prose errors")
    func hdcPlainTargetParser() throws {
        let output = """
        Connect server failed
        127.0.0.1:5555
        """

        let targets = TKHdcTargetListParser.parse(output)

        #expect(targets.map(\.target) == ["127.0.0.1:5555"])
        #expect(targets.map(\.state) == ["Connected"])
        #expect(targets.map(\.scope) == [.emulator])
        #expect(targets.map(\.kind) == ["emulator"])
        #expect(targets.map(\.blockedReasons) == [[]])
        #expect(TKHdcTargetListParser.defaultTarget(from: targets)?.target == "127.0.0.1:5555")
    }

    @Test("HDC target parser separates DevEco emulator and real devices")
    func hdcParserSeparatesEmulatorAndRealTargets() throws {
        let fixture = TKHarmonyHDCFakeFixture.targetsMixedEmulatorAndReal.result
        let targets = TKHdcTargetListParser.parse(fixture.stdoutString)

        #expect(TKHdcTargetListParser.targets(targets, matching: .emulator).map(\.target) == ["127.0.0.1:10100"])
        #expect(TKHdcTargetListParser.targets(targets, matching: .real).map(\.target) == ["HDCREAL001", "HDCREAL002"])
        #expect(TKHdcTargetListParser.targets(targets, matching: .real).map(\.kind) == ["real-device", "real-device"])
        #expect(TKHdcTargetListParser.targets(targets, matching: .real).map(\.blockedReasons) == [[], ["unauthorized"]])
        #expect(targets.first { $0.target == "HDCREAL001" }?.id.hasPrefix("harmony-real:") == true)
        #expect(targets.first { $0.target == "HDCREAL001" }?.id.contains("HDCREAL001") == false)
    }

    @Test("fake HDC runner replays real-device readiness probes")
    func fakeHDCRunnerReplaysRealDeviceReadinessProbes() throws {
        let target = "HDCREAL001"
        let runner = TKHarmonyHDCFakeRunner(fixtures: [
            .targetsRealConnected(target: target),
            .bootCompletedTrue(target: target),
            .shellAvailable(target: target),
        ])

        let list = try runner.run(TKHarmonyHDCCommand.listTargets())
        let boot = try runner.run(TKHarmonyHDCCommand.bootCompleted(target: target))
        let shell = try runner.run(TKHarmonyHDCCommand.shellProbe(target: target))

        #expect(TKHdcTargetListParser.parse(list.stdoutString).first?.scope == .real)
        #expect(TKHarmonyBootCompletedParser.isReady(boot.stdoutString))
        #expect(TKHarmonyShellProbeParser.isAvailable(stdout: shell.stdoutString, stderr: shell.stderrString, exitCode: shell.exitCode))

        let blockedRunner = TKHarmonyHDCFakeRunner(fixtures: [
            .targetsRealUnauthorized,
            .bootCompletedFalse(target: target),
            .shellUnavailable(target: target),
        ])
        let unauthorized = try blockedRunner.run(TKHarmonyHDCCommand.listTargets())
        let booting = try blockedRunner.run(TKHarmonyHDCCommand.bootCompleted(target: target))
        let unavailable = try blockedRunner.run(TKHarmonyHDCCommand.shellProbe(target: target))

        #expect(TKHdcTargetListParser.parse(unauthorized.stdoutString).first?.blockedReasons == ["unauthorized"])
        #expect(!TKHarmonyBootCompletedParser.isReady(booting.stdoutString))
        #expect(!TKHarmonyShellProbeParser.isAvailable(stdout: unavailable.stdoutString, stderr: unavailable.stderrString, exitCode: unavailable.exitCode))
    }

    @Test("Harmony foreground app parser extracts foreground bundle and app label")
    func harmonyForegroundAppParserCurrent() throws {
        let output = """
        User ID #100
          current mission lists:{
            Mission ID #139  mission name #[#com.example.demo:entry:EntryAbility]  lockedState #0
              AbilityRecord ID #55
                app name [Demo App]
                main name [EntryAbility]
                bundle name [com.example.demo]
                ability type [PAGE]
                state #FOREGROUND  start time [152523]
                app state #FOREGROUND
                ready #1  window attached #1  launcher #0
          }
        """

        let identity = TKHarmonyForegroundAppParser.parse(output)

        #expect(identity.appName == "Demo App")
        #expect(identity.bundleIdentifier == "com.example.demo")
        #expect(identity.identityState == "current")
        #expect(identity.current == true)
    }

    @Test("Harmony foreground app parser chooses the foreground mission identity")
    func harmonyForegroundAppParserChoosesForegroundMission() throws {
        let output = """
        Mission ID #11  mission name #[#com.example.background:entry:EntryAbility]
          AbilityRecord ID #21
            app name [Background App]
            bundle name [com.example.background]
            state #BACKGROUND
        Mission ID #12  mission name #[#com.example.foreground:entry:EntryAbility]
          AbilityRecord ID #22
            app name [Foreground App]
            bundle name [com.example.foreground]
            state #FOREGROUND
        """

        let identity = TKHarmonyForegroundAppParser.parse(output)

        #expect(identity.appName == "Foreground App")
        #expect(identity.bundleIdentifier == "com.example.foreground")
        #expect(identity.identityState == "current")
        #expect(identity.current == true)
    }

    @Test("Harmony foreground app parser reports unknown without fabricating identity")
    func harmonyForegroundAppParserUnknown() throws {
        let output = """
        User ID #100
          current mission lists:{
          }
        """

        let identity = TKHarmonyForegroundAppParser.parse(output)

        #expect(identity.appName == nil)
        #expect(identity.bundleIdentifier == nil)
        #expect(identity.identityState == "unknown")
        #expect(identity.current == false)
    }

    @Test("Harmony boot parser only treats true as ready")
    func harmonyBootCompletedParser() {
        #expect(TKHarmonyBootCompletedParser.isReady("true\n"))
        #expect(!TKHarmonyBootCompletedParser.isReady("false\n"))
        #expect(!TKHarmonyBootCompletedParser.isReady("1\n"))
        #expect(!TKHarmonyBootCompletedParser.isReady(""))
    }

    @Test("ADB device parser preserves emulator states and metadata")
    func adbDeviceParser() throws {
        let output = """
        List of devices attached
        emulator-5554          device product:sdk_gphone64_arm64 model:Pixel_8 device:emu64a transport_id:1
        emulator-5556          offline transport_id:2
        emulator-5558          unauthorized transport_id:3
        """

        let targets = TKAdbDeviceListParser.parse(output)

        #expect(targets.map(\.id) == ["android:emulator-5554", "android:emulator-5556", "android:emulator-5558"])
        #expect(targets.map(\.serial) == ["emulator-5554", "emulator-5556", "emulator-5558"])
        #expect(targets.map(\.state) == ["device", "offline", "unauthorized"])
        #expect(targets.filter(\.isReady).map(\.serial) == ["emulator-5554"])
        #expect(targets.first?.product == "sdk_gphone64_arm64")
        #expect(targets.first?.model == "Pixel_8")
        #expect(targets.first?.device == "emu64a")
        #expect(targets.first?.transportID == "1")
        #expect(TKAdbDeviceListParser.defaultTarget(from: targets)?.serial == "emulator-5554")
    }

    @Test("Android boot parser only treats one as ready")
    func androidBootCompletedParser() {
        #expect(TKAndroidBootCompletedParser.isReady("1\n"))
        #expect(!TKAndroidBootCompletedParser.isReady("0\n"))
        #expect(!TKAndroidBootCompletedParser.isReady("true\n"))
        #expect(!TKAndroidBootCompletedParser.isReady(""))
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
            "SeedState": Data([0x5B, 0x7B, 0x7D, 0x5D]),
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)

        let snapshot = try TKHostPreferencesSnapshot(bundleID: "com.example.app", plistPath: "/tmp/com.example.app.plist", data: data)

        #expect(snapshot.value(forKey: "DEBUG-mock") == .bool(false))
        #expect(snapshot.value(forKey: "ApplicationEnvironmentKey") == .int(3))
        #expect(snapshot.value(forKey: "Name") == .string("Demo"))
        #expect(snapshot.value(forKey: "Missing") == nil)
        #expect(snapshot.preferences["Nested"]?.kind == "dictionary")
        #expect(snapshot.preferences["List"]?.kind == "array")
        #expect(snapshot.preferences["SeedState"] == .data(Data([0x5B, 0x7B, 0x7D, 0x5D]).base64EncodedString()))
    }

    @Test("preference plist path is derived from data container and bundle id")
    func preferencePathDerivation() {
        let path = TKHostPreferencesSnapshot.plistPath(dataContainer: "/tmp/AppData", bundleID: "com.example.app")

        #expect(path == "/tmp/AppData/Library/Preferences/com.example.app.plist")
    }
}

private func devicectlListJSON(device: String) -> String {
    """
    {
      "info": { "jsonVersion": "2", "version": "1", "outcome": "success" },
      "result": {
        "devices": [
          \(device)
        ]
      }
    }
    """
}
