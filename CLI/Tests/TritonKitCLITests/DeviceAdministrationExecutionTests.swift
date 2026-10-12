import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Administration execution isolated contract")
struct DeviceAdministrationExecutionTests {
    private func options(_ args: [String] = []) throws -> DeviceAdministrationOptions {
        try DevicePair.parse(["--device", "fixture", "--execute-runner", "--confirm", "--audit-record", "fixture-audit"] + args).options
    }
    private func selection() -> HostDeviceSelectionResult {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "PRIVATE-NATIVE", state: "blocked", ready: false, blockedReasons: ["unpaired"]))
        return HostDeviceSelectionResult(platform: .ios, target: target, selector: "fixture", source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
    }
    private func result(_ command: TKHostCommand) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: hostSourceCommand(command), stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
    }
    private func support(_ spec: AppleHostCommandSpecification) -> HostAppleCommandSupport {
        HostAppleCommandSupport(name: spec.name, supported: true, requiredOptions: spec.requiredOptions, missingOptions: [], sourceCommand: "fixture-help", error: nil)
    }
    private func workspace() throws -> String {
        let url = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().appendingPathComponent(".triton-administration-fixture-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return url.path
    }
    @Test("native administration timeout is an integer while host deadline stays precise")
    func nativeTimeout() throws {
        for operation in [DeviceAdministrationOperation.pair, .unpair, .diagnose] {
            for value in [0.1, 1.0, 1.5, 30.0] {
                let command = plannedDeviceAdministrationCommand(operation: operation, nativeIdentifier: "PRIVATE-NATIVE", archiveDestination: "/private/archive.zip", timeout: value)
                let index = try #require(command.arguments.firstIndex(of: "--timeout"))
                #expect(command.arguments[index + 1] == String(format: "%.0f", ceil(value)))
                #expect(command.defaultTimeoutSeconds == value)
            }
        }
    }
    @Test("incomplete policy refuses before discovery or runner")
    func policy() throws {
        let value = try DevicePair.parse(["--device", "fixture", "--execute-runner"]).options
        var called = false
        #expect(throws: HostDeviceAdministrationError.self) {
            _ = try executeDeviceAdministration(operation: .pair, options: value, resolver: { _ in called = true; return selection() }, commandProbe: support, runner: { _ in called = true; throw HostDeviceAdministrationError.invalidResult }, workspaceProvider: { throw HostDeviceAdministrationError.auditFailed })
        }
        #expect(!called)
    }
    @Test("whitespace audit record refuses before discovery")
    func whitespaceAudit() throws {
        var value = try options(); value.auditRecord = "   "
        var called = false
        #expect(throws: HostDeviceAdministrationError.self) {
            _ = try executeDeviceAdministration(operation: .pair, options: value, resolver: { _ in called = true; return selection() }, commandProbe: support, runner: { _ in called = true; throw HostDeviceAdministrationError.invalidResult }, workspaceProvider: { throw HostDeviceAdministrationError.auditFailed })
        }
        #expect(!called)
    }
    @Test("unknown native result layouts cannot be promoted to verified success")
    func malformedNativeResult() throws {
        let command = plannedDeviceAdministrationCommand(operation: .pair, nativeIdentifier: "PRIVATE-NATIVE", archiveDestination: nil, timeout: 1)
        let malformed: [Any] = [NSNull(), "bad", [], ["devices": NSNull()], ["devices": "bad"], ["devices": []], ["devices": [["name": "missing-id"]]]]
        for result in malformed {
            let data = try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": command.arguments], "result": result])
            #expect(throws: HostDeviceAdministrationError.self) { try parseDeviceAdministrationResult(data, command: command, nativeIdentifier: "PRIVATE-NATIVE") }
        }
        let missing = try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": command.arguments]])
        #expect(throws: HostDeviceAdministrationError.self) { try parseDeviceAdministrationResult(missing, command: command, nativeIdentifier: "PRIVATE-NATIVE") }
    }
    @Test("native JSON must bind entire argv; result identifiers cannot contradict")
    func binding() throws {
        let command = plannedDeviceAdministrationCommand(operation: .pair, nativeIdentifier: "PRIVATE-NATIVE", archiveDestination: nil, timeout: 1)
        func payload(_ argv: [String], identifier: String? = nil) throws -> Data {
            var result: [String: Any] = [:]; if let identifier { result["identifier"] = identifier }
            return try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": argv], "result": result])
        }
        #expect(try parseDeviceAdministrationResult(payload(command.arguments), command: command, nativeIdentifier: "PRIVATE-NATIVE"))
        #expect(throws: HostDeviceAdministrationError.self) { try parseDeviceAdministrationResult(payload(command.arguments + ["--device", "OTHER"]), command: command, nativeIdentifier: "PRIVATE-NATIVE") }
        #expect(throws: HostDeviceAdministrationError.self) { try parseDeviceAdministrationResult(payload(command.arguments, identifier: "OTHER"), command: command, nativeIdentifier: "PRIVATE-NATIVE") }
    }
    @Test("failed outcome and contradictory error are not success")
    func nativeFailure() throws {
        let command = plannedDeviceAdministrationCommand(operation: .pair, nativeIdentifier: "PRIVATE-NATIVE", archiveDestination: nil, timeout: 1)
        let failed = try JSONSerialization.data(withJSONObject: ["info": ["outcome": "failed", "arguments": command.arguments], "error": ["code": 1]])
        #expect(try !parseDeviceAdministrationResult(failed, command: command, nativeIdentifier: "PRIVATE-NATIVE"))
        let contradictory = try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": command.arguments], "error": ["code": 1]])
        #expect(throws: HostDeviceAdministrationError.self) { try parseDeviceAdministrationResult(contradictory, command: command, nativeIdentifier: "PRIVATE-NATIVE") }
    }
    @Test("trust changes require fresh postcondition and durable before/after audit; failures never retry", arguments: [DeviceAdministrationOperation.pair, .unpair])
    func lifecycle(_ operation: DeviceAdministrationOperation) throws {
        for mode in ["success", "missing-postcondition", "trusted", "timeout", "failed", "bad-json"] {
            var calls = 0
            let directory = try workspace()
            defer { try? FileManager.default.removeItem(atPath: directory) }
            let output = try executeDeviceAdministration(operation: operation, options: options(), resolver: { _ in selection() }, commandProbe: support, runner: { command in
                calls += 1
                let directory = URL(fileURLWithPath: command.arguments[command.arguments.firstIndex(of: "--json-output")! + 1]).deletingLastPathComponent()
                #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("intent.json").path))
                if mode == "timeout" { throw HostCommandRunError.timeout(command: command, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil) }
                if mode == "failed" { throw HostCommandRunError.nonZeroExit(command: command, result: result(command)) }
                let data = mode == "bad-json" ? Data("{}".utf8) : try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": command.arguments], "result": [:]])
                try data.write(to: directory.appendingPathComponent("result.json"))
                return result(command)
            }, pairingProbe: { _, _, _ in mode == "success" ? (operation == .pair ? "paired" : "unpaired") : mode == "trusted" ? (operation == .pair ? "trusted" : "untrusted") : nil }, workspaceProvider: { directory })
            #expect(calls == 1 && output.executed && output.auditCompletionPersisted)
            #expect(output.verification == "native-file-json-and-independent-postcondition")
            #expect(!output.limitations.contains { $0.contains("implementation task") })
            #expect(output.status == (mode == "success" ? "succeeded" : mode == "timeout" ? "timed-out" : mode == "failed" ? "failed" : "partial"))
            #expect(output.ok == (mode == "success"))
            #expect(!(try encodeJSON(output)).contains("PRIVATE-NATIVE"))
        }
    }
    @Test("modern postcondition key suppresses stale legacy pairing including null or wrong type")
    func postconditionPrecedence() throws {
        let command = TKHostCommand(arguments: ["devicectl", "device", "info", "details", "--device", "PRIVATE-NATIVE"])
        for modern: Any in [NSNull(), "bad", [:], ["connection": NSNull()], ["connection": ["pairingState": "unknown"]], ["connection": ["pairingState": "trusted"]], ["connection": ["pairingState": "untrusted"]]] {
            let data = try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": command.arguments], "result": ["identifier": "PRIVATE-NATIVE", "properties": modern, "connectionProperties": ["pairingState": "paired"]]])
            #expect(try parseAdministrationPairingPostcondition(data, command: command, nativeIdentifier: "PRIVATE-NATIVE") == nil)
        }
        let legacy = try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": command.arguments], "result": ["identifier": "PRIVATE-NATIVE", "connectionProperties": ["pairingState": "paired"]]])
        #expect(try parseAdministrationPairingPostcondition(legacy, command: command, nativeIdentifier: "PRIVATE-NATIVE") == "paired")
    }
    @Test("ZIP local payload metadata accepted only within central-directory boundary")
    func localEntryBoundaries() throws {
        let directory = try workspace()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        var local = [UInt8](repeating: 0, count: 31)
        local.replaceSubrange(0..<4, with: [0x50,0x4b,0x03,0x04]); local[26] = 1; local[30] = 0x61
        var central = [UInt8](repeating: 0, count: 47)
        central.replaceSubrange(0..<4, with: [0x50,0x4b,0x01,0x02]); central[28] = 1; central[46] = 0x61
        var eocd = [UInt8](repeating: 0, count: 22)
        eocd.replaceSubrange(0..<4, with: [0x50,0x4b,0x05,0x06]); eocd[8] = 1; eocd[10] = 1; eocd[12] = 47; eocd[16] = 31
        for mutation in ["valid", "payload-overlap", "local-name", "local-offset", "missing-descriptor"] {
            var l = local, c = central
            if mutation == "payload-overlap" { c[20] = 1; l[18] = 1 }
            if mutation == "local-name" { l[30] = 0x62 }
            if mutation == "local-offset" { c[42] = 31 }
            if mutation == "missing-descriptor" { l[6] = 8; c[8] = 8 }
            let source = directory + "/" + mutation + ".zip", destination = directory + "/" + mutation + "-output.zip"
            try Data(l + c + eocd).write(to: URL(fileURLWithPath: source))
            let publisher = try DeviceDiagnosticArchive(destination: destination, maximumBytes: 1024)
            if mutation == "valid" { #expect(try publisher.publish(source: source) == 100) }
            else { #expect(throws: HostDeviceAdministrationError.self) { try publisher.publish(source: source) } }
        }
    }
    @Test("forged central directory without local entry is rejected")
    func forgedCentralDirectory() throws {
        let directory = try workspace()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        var central = [UInt8](repeating: 0, count: 47)
        central.replaceSubrange(0..<4, with: [0x50,0x4b,0x01,0x02]); central[28] = 1; central[46] = 0x61
        var eocd = [UInt8](repeating: 0, count: 22)
        eocd.replaceSubrange(0..<4, with: [0x50,0x4b,0x05,0x06]); eocd[8] = 1; eocd[10] = 1; eocd[12] = 47
        let source = directory + "/forged.zip"
        try Data(central + eocd).write(to: URL(fileURLWithPath: source))
        let publisher = try DeviceDiagnosticArchive(destination: directory + "/rejected.zip", maximumBytes: 1024)
        #expect(throws: HostDeviceAdministrationError.self) { try publisher.publish(source: source) }
        #expect(!FileManager.default.fileExists(atPath: directory + "/rejected.zip"))
    }
    @Test("audit preparation failure prevents native invocation")
    func auditFailure() throws {
        var called = false
        #expect(throws: HostDeviceAdministrationError.self) {
            _ = try executeDeviceAdministration(operation: .pair, options: options(), resolver: { _ in selection() }, commandProbe: support, runner: { command in called = true; return result(command) }, workspaceProvider: { throw HostDeviceAdministrationError.auditFailed })
        }
        #expect(!called)
    }
    @Test("diagnostic executable backend uses staging then private no-overwrite ZIP publication")
    func diagnosticExecution() throws {
        let directory = try workspace()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let destination = directory + "/published.zip"
        let value = try DeviceDiagnose.parse(["--device", "fixture", "--execute-runner", "--confirm", "--audit-record", "fixture-audit", "--output", destination]).options
        let output = try executeDeviceAdministration(operation: .diagnose, options: value, resolver: { _ in selection() }, commandProbe: support, runner: { command in
            let archive = command.arguments[command.arguments.firstIndex(of: "--archive-destination")! + 1]
            #expect(archive != destination && command.arguments.filter { $0 == "--devices" }.count == 1)
            #expect(command.arguments.contains("--no-finder") && command.arguments.contains("--no-include-host-sysdiagnose"))
            try Data([0x50,0x4b,0x05,0x06] + Array(repeating: UInt8(0), count: 18)).write(to: URL(fileURLWithPath: archive))
            let json = command.arguments[command.arguments.firstIndex(of: "--json-output")! + 1]
            try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "arguments": command.arguments], "result": [:]]).write(to: URL(fileURLWithPath: json))
            return result(command)
        }, workspaceProvider: { directory })
        #expect(output.ok && output.diagnosticArchiveVerified && output.archiveBytes == 22)
        #expect(!(try encodeJSON(output)).contains(destination))
    }
    @Test("renamed diagnostic output parent cannot be reported as the requested destination")
    func diagnosticDestinationReplacement() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let parent = root + "/destination", moved = root + "/moved"
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let source = root + "/source.zip"
        try Data([0x50,0x4b,0x05,0x06] + Array(repeating: UInt8(0), count: 18)).write(to: URL(fileURLWithPath: source))
        let publisher = try DeviceDiagnosticArchive(destination: parent + "/output.zip", maximumBytes: 1024)
        try FileManager.default.moveItem(atPath: parent, toPath: moved)
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        #expect(throws: HostDeviceAdministrationError.self) { try publisher.publish(source: source) }
        #expect(!FileManager.default.fileExists(atPath: parent + "/output.zip"))
        #expect(!FileManager.default.fileExists(atPath: moved + "/output.zip"))
    }
    @Test("archive destination denies existing files and symlink parents; publication private and bounded")
    func archive() throws {
        let directory = try workspace()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let source = directory + "/source.zip", destination = directory + "/published.zip"
        // Minimal valid empty ZIP end-of-central-directory record.
        try Data([0x50,0x4b,0x05,0x06] + Array(repeating: UInt8(0), count: 18)).write(to: URL(fileURLWithPath: source))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: source)
        let publisher = try DeviceDiagnosticArchive(destination: destination, maximumBytes: 1024)
        #expect(try publisher.publish(source: source) == 22)
        var info = stat(); #expect(lstat(destination, &info) == 0 && info.st_mode & 0o777 == 0o600)
        #expect(throws: HostDeviceAdministrationError.self) { try DeviceDiagnosticArchive(destination: destination, maximumBytes: 1024) }
        let tooSmall = try DeviceDiagnosticArchive(destination: directory + "/small.zip", maximumBytes: 21)
        #expect(throws: HostDeviceAdministrationError.self) { try tooSmall.publish(source: source) }
        #expect(!FileManager.default.fileExists(atPath: directory + "/small.zip"))
        try FileManager.default.createSymbolicLink(atPath: directory + "/link", withDestinationPath: directory)
        #expect(throws: HostDeviceAdministrationError.self) { try DeviceDiagnosticArchive(destination: directory + "/link/unsafe.zip", maximumBytes: 1024) }
    }
}
