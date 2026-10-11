import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Bound native app containers")
struct AppContainerBindingTests {
    let udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    let container = "11111111-2222-3333-4444-555555555555"
    let home = "/private/FIXTURE-HOME"
    func selection(real: Bool = false) -> HostDeviceSelectionResult {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: udid, state: "unknown", ready: false, blockedReasons: [], scope: real ? "real" : "simulator", kind: real ? "real-device" : "simulator", simulatorUDID: real ? nil : udid))
        return HostDeviceSelectionResult(platform: .ios, target: target, selector: target.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
    }
    var nativePath: String { home + "/Library/Developer/CoreSimulator/Devices/" + udid + "/data/Containers/Data/Application/" + container }
    func result(_ text: String = "") -> HostProcessResult { HostProcessResult(stdoutData: Data(text.utf8), stderrData: Data(), exitCode: 0, sourceCommand: "private", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: text.utf8.count, stderrBytes: 0) }
    var help: String { "--bundle-id --include-all-apps --include-container-paths --include-app-group-identifiers --device --json-output --log-output" }
    func fixture(device: String? = nil, path: String? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["info": ["commandType": "devicectl.device.info.apps", "outcome": "success", "arguments": ["--device", udid, "--bundle-id", "example.app", "--include-all-apps", "--include-container-paths", "--include-app-group-identifiers"]], "result": ["deviceIdentifier": device ?? udid, "apps": [["bundleIdentifier": "example.app", "containerAccessible": true, "dataContainerPath": path ?? nativePath]]]])
    }
    @Test func onlyExactSimulatorRootAccepted() throws {
        #expect(try boundSimulatorAppContainerPath(path: nativePath, selection: selection(), group: false, homeDirectory: home) == nativePath)
        for path in [nativePath + "/Library", nativePath.replacingOccurrences(of: udid, with: container), nativePath.replacingOccurrences(of: "CoreSimulator", with: "CoreDevice/DeviceFS"), nativePath + "/../escape"] {
            #expect(throws: HostAppContainerBindingError.rootMismatch) { _ = try boundSimulatorAppContainerPath(path: path, selection: selection(), group: false, homeDirectory: home) }
        }
    }
    @Test func privacyAndShallowListing() throws {
        var calls = 0
        let output = try makeAppContainerBindingOutput(selection: selection(), bundleIdentifier: "example.app", list: true, homeDirectory: home, artifactProvider: { _ in ("/fixture/apps.json", "/fixture/apps.log") }, runner: { command in calls += 1; return result(command.arguments.contains("--help") ? help : "PRIVATE-STDOUT") }, reader: { _, _ in try fixture() }, listReader: { root, relative, _ in
            #expect(root == home + "/Library/Developer/CoreSimulator/Devices/" + udid && relative == "data/Containers/Data/Application/" + container)
            return [DeviceFSMetadataEntry(name: "PRIVATE-LEAF", kind: "regular-file", sizeBytes: 7)]
        })
        #expect(calls == 2 && output.bindingStatus == "sdk-bound" && output.hostFilesystemInspected && output.count == 1 && !output.contentsRead)
        let encoded = try encodeJSON(output)
        for secret in ["example.app", "PRIVATE-LEAF", "PRIVATE-STDOUT", nativePath] { #expect(!encoded.contains(secret)) }
    }
    @Test func oldSDKAndRealListingFailBeforeQuery() throws {
        var artifacts = 0
        #expect(throws: HostAppContainerBindingError.unsupportedSDK) { _ = try makeAppContainerBindingOutput(selection: selection(), bundleIdentifier: "example.app", artifactProvider: { _ in artifacts += 1; return ("", "") }, runner: { _ in result("--device --json-output") }) }
        #expect(artifacts == 0)
        #expect(throws: HostAppContainerBindingError.unsupportedListing) { _ = try makeAppContainerBindingOutput(selection: selection(real: true), bundleIdentifier: "example.app", list: true, artifactProvider: { _ in artifacts += 1; return ("", "") }, runner: { _ in Issue.record("must not execute"); return result() }) }
        #expect(artifacts == 0)
    }
    @Test func wrongResultIdentityStopsFilesystemRead() throws {
        #expect(throws: HostAppContainerBindingError.identityMismatch) { _ = try makeAppContainerBindingOutput(selection: selection(), bundleIdentifier: "example.app", list: true, artifactProvider: { _ in ("/fixture/apps.json", "/fixture/apps.log") }, runner: { _ in result(help) }, reader: { _, _ in try fixture(device: container) }, listReader: { _, _, _ in Issue.record("unbound filesystem access"); return [] }) }
    }
    @Test func metadataOnlyNeverTouchesFilesystemAndLegacyIsUnavailable() throws {
        let output = try makeAppContainerBindingOutput(selection: selection(real: true), bundleIdentifier: "example.app", artifactProvider: { _ in ("/fixture/apps.json", "/fixture/apps.log") }, runner: { _ in result(help) }, reader: { _, _ in
            var root = try #require(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
            root["result"] = ["deviceIdentifier": udid, "apps": [["bundleIdentifier": "example.app"]]]
            return try JSONSerialization.data(withJSONObject: root)
        }, listReader: { _, _, _ in Issue.record("metadata only must not inspect filesystem"); return [] })
        #expect(output.bindingStatus == "unavailable" && output.containerToken == nil && !output.hostFilesystemInspected && output.entries.isEmpty)
    }
    @Test func boundedReadersAndTimeoutRemainAccurate() throws {
        #expect(throws: HostAppContainerBindingError.timeout) { _ = try makeAppContainerBindingOutput(selection: selection(), bundleIdentifier: "example.app", runner: { command in throw HostCommandRunError.timeout(command: command, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil) }) }
        #expect(throws: HostAppContainerBindingError.limitExceeded) { _ = try makeAppContainerBindingOutput(selection: selection(), bundleIdentifier: "example.app", artifactProvider: { _ in ("/fixture/apps.json", "/fixture/apps.log") }, runner: { _ in result(help) }, reader: { _, _ in throw HostDeviceFilesError.limitExceeded }) }
        #expect(throws: HostAppContainerBindingError.limitExceeded) { _ = try makeAppContainerBindingOutput(selection: selection(), bundleIdentifier: "example.app", list: true, maximumEntries: 1, homeDirectory: home, artifactProvider: { _ in ("/fixture/apps.json", "/fixture/apps.log") }, runner: { _ in result(help) }, reader: { _, _ in try fixture() }, listReader: { _, _, _ in [DeviceFSMetadataEntry(name: "a", kind: "directory", sizeBytes: nil), DeviceFSMetadataEntry(name: "b", kind: "directory", sizeBytes: nil)] }) }
    }

}
