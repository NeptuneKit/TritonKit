import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("DeviceFS independent mountpoint query")
struct DeviceMountpointTests {
    private let fixture = Data(#"{"info":{"arguments":["devicectl","device","info","mountpoint","--device","CORE-PRIVATE"],"commandType":"devicectl.device.info.mountpoint","outcome":"success"},"result":{"dataPath":"/not-existing/SECRET-PATH/device-CORE-PRIVATE.localized"}}"#.utf8)
    private func selection(platform: HostDevicePlatform = .ios) -> HostDeviceSelectionResult {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "CORE-PRIVATE", state: "unknown", ready: false, blockedReasons: [], alternateIdentifiers: ["STALE-ALIAS"]))
        return HostDeviceSelectionResult(platform: platform, target: target, selector: target.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: platform)))
    }
    private func artifacts(_ action: String) -> (json: String, log: String) { ("/fixture/\(action).json", "/fixture/\(action).log") }
    private func result(_ command: TKHostCommand, exit: Int32 = 0) -> HostProcessResult {
        HostProcessResult(stdoutData: fixture, stderrData: Data("SECRET-STDERR".utf8), exitCode: exit, sourceCommand: "UNTRUSTED CORE-PRIVATE SECRET-PATH", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
    }
    @Test("bound token output remains successful for nonexistent private path without filesystem claims")
    func privacy() throws {
        var commands: [TKHostCommand] = []
        let output = try makeIOSDeviceMountpointOutput(selection: selection(), timeout: 12, artifactProvider: artifacts, runner: { command in commands.append(command); return result(command) }, reader: { _, _ in fixture })
        #expect(commands.count == 1 && commands[0].defaultTimeoutSeconds == 12 && commands[0].riskLevel == .readonly)
        #expect(commands[0].arguments.prefix(6) == ["devicectl", "device", "info", "mountpoint", "--device", "CORE-PRIVATE"])
        #expect(commands[0].redactedArgumentIndexes.contains(5))
        #expect(!output.hostFilesystemInspected && !output.mountStateVerified && !output.contentsListed && !output.businessReadinessVerified)
        #expect(output.mountpointToken.hasPrefix("devicefs:") && output.mountpointToken.count == 73)
        let encoded = try encodeJSON(output)
        for secret in ["CORE-PRIVATE", "STALE-ALIAS", "SECRET-PATH", "UNTRUSTED", "SECRET-STDERR", "dataPath"] { #expect(!encoded.contains(secret)) }
        let baseline = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in fixture })
        #expect(output.mountpointToken == baseline.mountpointToken)
    }
    @Test("echo must exactly match submitted primary identity, never a stale physical alias", arguments: ["OTHER", "STALE-ALIAS"])
    func mismatch(identifier: String) throws {
        let changed = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "CORE-PRIVATE", with: identifier).utf8)
        #expect(throws: HostDeviceMountpointError.identityMismatch) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in changed }) }
        let contradicted = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "\"dataPath\":", with: "\"deviceIdentifier\":\"" + identifier + "\",\"dataPath\":").utf8)
        #expect(throws: HostDeviceMountpointError.identityMismatch) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in contradicted }) }
    }
    @Test("missing/malformed/oversized JSON fails without parsing valid human stdout")
    func jsonFailures() throws {
        #expect(throws: HostDeviceMountpointError.jsonMissing) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in throw CocoaError(.fileReadNoSuchFile) }) }
        #expect(throws: HostDeviceMountpointError.invalidJSON) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in Data([0xff]) }) }
        #expect(throws: HostDeviceMountpointError.limitExceeded) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), maximumJSONBytes: 1, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in fixture }) }
        #expect(throws: HostDeviceMountpointError.limitExceeded) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in throw HostDeviceFilesError.limitExceeded }) }
    }
    @Test("nonzero and timeout fail once, without JSON fallback or unsupported-feature guessing", arguments: [false, true])
    func nonzero(thrown: Bool) throws {
        var count = 0
        #expect(throws: HostDeviceMountpointError.queryFailed) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { command in count += 1; if thrown { throw HostCommandRunError.nonZeroExit(command: command, result: result(command, exit: 1)) }; return result(command, exit: 1) }, reader: { _, _ in Issue.record("No failure JSON interpretation/fallback"); return fixture }) }
        #expect(count == 1)
        #expect(throws: HostDeviceMountpointError.timeout) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), artifactProvider: artifacts, runner: { command in throw HostCommandRunError.timeout(command: command, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil) }, reader: { _, _ in Issue.record("No timeout JSON read"); return fixture }) }
    }
    @Test("invalid budget/timeouts/platform fail before IO and limits recover through diagnosis/planning")
    func preflight() throws {
        #expect(throws: HostDeviceMountpointError.unsupportedPlatform) { _ = try makeIOSDeviceMountpointOutput(selection: selection(platform: .android), artifactProvider: { _ in Issue.record("No IO"); return ("", "") }) }
        for (bytes, timeout) in [(0, 1.0), (16_777_217, 1.0), (1, Double.nan), (1, Double.infinity), (1, -1.0)] {
            #expect(throws: HostDeviceSelectionError.self) { _ = try makeIOSDeviceMountpointOutput(selection: selection(), timeout: timeout, maximumJSONBytes: bytes, artifactProvider: { _ in Issue.record("No IO"); return ("", "") }) }
        }
        #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "device_mountpoint_limit_exceeded") == ["diagnose", "plan"])
    }
    @Test("optional result UUID normalization never weakens exact echo or admits physical aliases")
    func uuidSemantics() throws {
        let primary = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: primary, state: "unknown", ready: false, blockedReasons: [], alternateIdentifiers: ["STALE-ALIAS"]))
        let chosen = HostDeviceSelectionResult(platform: .ios, target: target, selector: target.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
        let raw = String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "CORE-PRIVATE", with: primary).replacingOccurrences(of: "\"dataPath\":", with: "\"deviceIdentifier\":\"" + primary.lowercased() + "\",\"dataPath\":")
        let good = try makeIOSDeviceMountpointOutput(selection: chosen, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in Data(raw.utf8) })
        #expect(good.identityBinding == "exact-file-json-device-argument")
        let changedEcho = raw.replacingOccurrences(of: "\"--device\",\"" + primary + "\"", with: "\"--device\",\"" + primary.lowercased() + "\"")
        #expect(throws: HostDeviceMountpointError.identityMismatch) { _ = try makeIOSDeviceMountpointOutput(selection: chosen, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in Data(changedEcho.utf8) }) }
        let aliasResult = raw.replacingOccurrences(of: "\"deviceIdentifier\":\"" + primary.lowercased() + "\"", with: "\"deviceIdentifier\":\"STALE-ALIAS\"")
        #expect(throws: HostDeviceMountpointError.identityMismatch) { _ = try makeIOSDeviceMountpointOutput(selection: chosen, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in Data(aliasResult.utf8) }) }
    }
    @Test("mountpoint dispatch is standalone and legacy info/files stay registered")
    func dispatch() throws {
        let command = try TritonKitCLI.parseAsRoot(["device", "mountpoint", "--device", "fixture", "--json"])
        #expect(type(of: command).configuration.commandName == "mountpoint")
        #expect(type(of: try TritonKitCLI.parseAsRoot(["device", "info", "--json"])).configuration.commandName == "info")
        #expect(type(of: try TritonKitCLI.parseAsRoot(["device", "files", "--domain-type", "systemCrashLogs", "--json"])).configuration.commandName == "files")
    }
    @Test("machine schema declares private token metadata and not filesystem inspection")
    func schema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form.hasPrefix("mountpoint ") })
        let contract = try #require(schema.outputContracts.first { $0.selector == "host.device-mountpoint" })
        #expect(contract.fields.contains { $0.name == "mountpointToken" })
        #expect(contract.fields.contains { $0.name == "hostFilesystemInspected" })
        #expect(schema.failureCodes.contains("device_mountpoint_identity_mismatch"))
    }
}
