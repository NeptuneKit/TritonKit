import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Device Hub readonly information")
struct DeviceInfoTests {
    @Test("device info is dispatched from the root with legacy output options")
    func rootDispatch() throws {
        #expect(throws: Never.self) {
            _ = try TritonKitCLI.parseAsRoot(["device", "info", "--platform", "ios", "--device", "sim:fixture", "--lock-state", "--timeout", "12", "--json"])
        }
    }

    @Test("device schema advertises standalone readonly information and exact lock semantics")
    func schemaContract() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form.hasPrefix("info --platform ios") })
        #expect(schema.outputSemantics?.contains("passcodeRequired") == true)
        #expect(schema.outputSemantics?.contains("unlockedSinceBoot") == true)
        let contract = try #require(schema.outputContracts.first { $0.selector == "host.device-info" })
        #expect(contract.model == "HostDeviceInfoOutput")
        #expect(contract.fields.contains { $0.name == "lockState" })
        #expect(contract.fields.contains { $0.name == "hardware.platformObservation" && !$0.required })
        #expect(contract.fields.contains { $0.name == "hardware.platformObservation.systemFamily" })
        #expect(contract.fields.contains { $0.name == "hardware.platformObservation.sourceLayout" })
        #expect(schema.failureCodes.contains("unsupported_device_info_query"))
        #expect(schema.failureCodes.contains("device_info_identity_mismatch"))
    }

    private func selection(platform: HostDevicePlatform = .ios) -> HostDeviceSelectionResult {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "CORE-PRIVATE", state: "unknown", ready: false, blockedReasons: ["readiness-unknown"], alternateIdentifiers: ["PRIVATE-UDID"]))
        return HostDeviceSelectionResult(platform: platform, target: target, selector: target.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: platform)))
    }
    private let details = Data(#"{"info":{"outcome":"success"},"result":{"identifier":"CORE-PRIVATE","properties":{"hardware":{"reality":"physical","platform":"iOS","productType":"Fixture,1","serialNumber":"SECRET-SERIAL","udid":"PRIVATE-UDID"},"state":{"name":"Fixture","bootState":"booted"},"connection":{"pairingState":"paired","state":"connected","tunnelIPAddress":"SECRET-IP"}}}}"#.utf8)
    private let lock = Data(#"{"result":{"deviceIdentifier":"PRIVATE-UDID","passcodeRequired":false,"unlockedSinceBoot":true}}"#.utf8)
    private func artifacts(_ action: String) -> (json: String, log: String) { ("/fixture/\(action).json", "/fixture/\(action).log") }
    private func result(_ command: TKHostCommand, exit: Int32 = 0) -> HostProcessResult {
        HostProcessResult(stdoutData: Data("SECRET-STDOUT".utf8), stderrData: Data("SECRET-STDERR".utf8), exitCode: exit, sourceCommand: "query CORE-PRIVATE PRIVATE-UDID", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
    }

    @Test("readonly details and optional lock queries honor timeout and redact every private alias", arguments: [false, true])
    func queryContract(lockRequested: Bool) throws {
        var commands: [TKHostCommand] = []
        let output = try makeIOSDeviceInfoOutput(selection: selection(), includeLockState: lockRequested, timeout: 12, artifactProvider: artifacts, runner: { command in
            commands.append(command)
            return result(command)
        }, reader: { path in path.contains("lockState") ? lock : details })
        #expect(commands.count == (lockRequested ? 2 : 1))
        #expect(commands.map { $0.arguments[3] } == (lockRequested ? ["details", "lockState"] : ["details"]))
        #expect(commands.allSatisfy { $0.riskLevel == .readonly && $0.defaultTimeoutSeconds == 12 && $0.capturesArtifacts && $0.sensitiveOutput && $0.redactedArgumentIndexes.contains(5) })
        #expect(output.lockState.requested == lockRequested)
        #expect(output.lockState.passcodeRequired == (lockRequested ? false : nil))
        #expect(output.lockState.unlockedSinceBoot == (lockRequested ? true : nil))
        #expect(output.businessReadinessVerified == false)
        let observation = try #require(output.hardware.platformObservation)
        #expect(observation.systemFamily == .ios && observation.deviceFamily == .unknown && observation.reality == .physical)
        #expect(observation.sourceLayout == "modern-properties-hardware" && observation.authority == "explicit-sdk-hardware-only")
        #expect(!observation.legacyNamespaceIsOperatingSystemProof && !observation.actionCapabilitiesVerified && !observation.businessReadinessVerified)
        let nested = try #require((JSONSerialization.jsonObject(with: Data(try encodeJSON(output).utf8)) as? [String: Any])?["hardware"] as? [String: Any])
        #expect((nested["platformObservation"] as? [String: Any])?["systemFamily"] as? String == "ios")
        let encoded = try encodeJSON(output)
        for secret in ["CORE-PRIVATE", "PRIVATE-UDID", "SECRET-SERIAL", "SECRET-IP", "SECRET-STDOUT", "SECRET-STDERR", "screenLocked", "rawTargetAliases"] {
            #expect(!encoded.contains(secret))
        }
    }

    @Test("details/lock mismatches cannot publish a successful snapshot", arguments: [false, true])
    func mismatch(lockMismatch: Bool) {
        let wrongDetails = Data(String(decoding: details, as: UTF8.self).replacingOccurrences(of: "CORE-PRIVATE", with: "OTHER").replacingOccurrences(of: "PRIVATE-UDID", with: "OTHER-UDID").utf8)
        let wrongLock = Data(#"{"result":{"deviceIdentifier":"OTHER","passcodeRequired":false}}"#.utf8)
        #expect(throws: HostDeviceInfoError.identityMismatch) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(), includeLockState: lockMismatch, artifactProvider: artifacts, runner: { result($0) }, reader: { path in
                path.contains("lockState") ? wrongLock : (lockMismatch ? details : wrongDetails)
            })
        }
    }

    @Test("a different physical CoreDevice record cannot validate itself with a stale hardware alias")
    func stalePhysicalAlias() {
        let wrong = Data(String(decoding: details, as: UTF8.self).replacingOccurrences(of: "CORE-PRIVATE", with: "OTHER-CORE").utf8)
        #expect(throws: HostDeviceInfoError.identityMismatch) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _ in wrong })
        }
    }

    @Test("backend failures are not retried or masked by another backend")
    func backendFailure() {
        var calls = 0
        #expect(throws: HostDeviceInfoError.queryFailed("details")) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(), includeLockState: true, artifactProvider: artifacts, runner: { command in calls += 1; return result(command, exit: 1) }, reader: { _ in Issue.record("Failed backend must not read a JSON file"); return details })
        }
        #expect(calls == 1)
    }

    @Test("unsupported platforms are rejected before artifacts and host commands")
    func unsupported() {
        #expect(throws: HostDeviceInfoError.unsupportedPlatform) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(platform: .android), artifactProvider: { _ in Issue.record("No artifacts"); return ("", "") }, runner: { command in Issue.record("No host query"); return result(command) })
        }
    }

    @Test("timeout invalid values fail before querying", arguments: [0.0, -1.0, Double.infinity, Double.nan])
    func invalidTimeout(timeout: Double) {
        #expect(throws: HostDeviceSelectionError.self) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(), timeout: timeout, artifactProvider: { _ in Issue.record("No artifacts"); return ("", "") })
        }
    }

    @Test("nil preserves readonly command timeout and full common argv")
    func defaultBudget() throws {
        var command: TKHostCommand?
        _ = try makeIOSDeviceInfoOutput(selection: selection(), artifactProvider: artifacts, runner: { value in command = value; return result(value) }, reader: { _ in details })
        let captured = try #require(command)
        let paths = artifacts("device-info-details")
        #expect(captured == redactingXcodeRealDeviceCommand(TKDevicectlCommand.deviceInfoDetails(identifier: "CORE-PRIVATE", jsonOutput: paths.json, logOutput: paths.log), rawTarget: "CORE-PRIVATE"))
    }

    @Test("missing and malformed JSON fail without using human stdout", arguments: [false, true])
    func invalidArtifacts(missing: Bool) {
        enum FixtureError: Error { case missing }
        #expect(throws: missing ? HostDeviceInfoError.jsonMissing : HostDeviceInfoError.invalidJSON) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(), artifactProvider: artifacts, runner: { result($0) }, reader: { _ in
                if missing { throw FixtureError.missing }
                return Data("invalid SECRET-JSON".utf8)
            })
        }
    }

    @Test("second query failure cannot publish a partial success envelope")
    func lockFailure() {
        #expect(throws: HostDeviceInfoError.queryFailed("lockState")) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(), includeLockState: true, artifactProvider: artifacts, runner: { result($0, exit: $0.arguments[3] == "lockState" ? 1 : 0) }, reader: { _ in details })
        }
    }

    @Test("CoreDevice structured capability rejection is not a generic lock failure", arguments: [false, true])
    func lockUnsupported(throwingRunner: Bool) {
        let failure = Data(#"{"info":{"outcome":"failed"},"error":{"domain":"com.apple.dt.CoreDeviceError","code":1001,"userInfo":{"CapabilityFeatureIdentifier":{"string":"com.apple.coredevice.feature.getlockstate"}}}}"#.utf8)
        #expect(throws: HostDeviceInfoError.queryUnsupported("lockState")) {
            _ = try makeIOSDeviceInfoOutput(selection: selection(), includeLockState: true, artifactProvider: artifacts, runner: { command in
                let output = result(command, exit: command.arguments[3] == "lockState" ? 1 : 0)
                if throwingRunner && output.exitCode != 0 { throw HostCommandRunError.nonZeroExit(command: command, result: output) }
                return output
            }, reader: { path in path.contains("lockState") ? failure : details })
        }
    }

    @Test("simulator details validate UDID against private CoreDevice identity")
    func simulatorDetails() throws {
        let udid = "12345678-ABCD-1234-ABCD-123456789ABC"
        let device = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: udid, state: "Booted", ready: true, blockedReasons: [], scope: "simulator", kind: "simulator", simulatorUDID: udid))
        let selected = HostDeviceSelectionResult(platform: .ios, target: device, selector: device.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
        let data = Data("{\"result\":{\"identifier\":\"PRIVATE-CORE-SIM\",\"properties\":{\"hardware\":{\"reality\":\"simulated\",\"platform\":\"iOS\",\"udid\":\"\(udid.lowercased())\"},\"state\":{\"bootState\":\"booted\"}}}}".utf8)
        let output = try makeIOSDeviceInfoOutput(selection: selected, artifactProvider: artifacts, runner: { result($0) }, reader: { _ in data })
        #expect(output.target.id == "sim:\(udid)")
        #expect(!String(decoding: try JSONEncoder().encode(output), as: UTF8.self).contains("PRIVATE-CORE-SIM"))
    }

    @Test("root parser preserves actual device info options and defaults")
    func parsedValues() throws {
        let command = try #require(TritonKitCLI.parseAsRoot(["device", "info", "--device", "sim:fixture", "--lock-state", "--timeout", "12", "--json"]) as? DeviceInfo)
        #expect(command.platform == .ios)
        #expect(command.device == "sim:fixture")
        #expect(command.scope == nil)
        #expect(command.timeout == 12)
        #expect(command.lockState && command.json)
        let defaults = try #require(TritonKitCLI.parseAsRoot(["device", "info"]) as? DeviceInfo)
        #expect(defaults.timeout == nil && !defaults.lockState)
    }
}
