import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Device Hub shallow file metadata")
struct DeviceFilesTests {
    @Test("files is an independent root command, not a mandatory workflow")
    func rootDispatch() throws {
        let command = try TritonKitCLI.parseAsRoot(["device", "files", "--device", "fixture", "--domain-type", "systemCrashLogs", "--json"])
        #expect(type(of: command).configuration.commandName == "files")
    }
    private func selection(platform: HostDevicePlatform = .ios) -> HostDeviceSelectionResult {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "CORE-PRIVATE", state: "unknown", ready: false, blockedReasons: [], alternateIdentifiers: ["STALE-ALIAS"]))
        return HostDeviceSelectionResult(platform: platform, target: target, selector: target.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: platform)))
    }
    private let fixture = Data(#"{"result":{"deviceIdentifier":"CORE-PRIVATE","domain":"systemCrashLogs","files":[{"name":"Secret.ips","relativePath":"Secret.ips","metadata":{"size":42,"ownerUid":501,"extendedAttributes":{"private":"SECRET-XATTR"}},"resources":{"isDirectory":false,"isSymbolicLink":false,"isWritable":true}}]}}"#.utf8)
    private let failed = Data(#"{"info":{"outcome":"failed"},"error":{"code":1001,"domain":"com.apple.dt.CoreDeviceError","userInfo":{"CapabilityFeatureIdentifier":{"string":"com.apple.coredevice.feature.listFiles"}}}}"#.utf8)
    private func artifacts(_ action: String) -> (json: String, log: String) { ("/fixture/\(action).json", "/fixture/\(action).log") }
    private func result(_ command: TKHostCommand, exit: Int32 = 0) -> HostProcessResult {
        HostProcessResult(stdoutData: Data("SECRET-STDOUT".utf8), stderrData: Data("SECRET-STDERR".utf8), exitCode: exit, sourceCommand: "UNTRUSTED CORE-PRIVATE", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
    }
    @Test("default metadata excludes file names/content/owners/xattrs/raw identity; opt-in exposes names only", arguments: [false, true])
    func privacy(sensitive: Bool) throws {
        var commands: [TKHostCommand] = []
        let request = try TKDevicectlFilesRequest(domain: "systemCrashLogs")
        let output = try makeIOSDeviceFilesOutput(selection: selection(), request: request, includeSensitive: sensitive, timeout: 12, artifactProvider: artifacts, runner: { command in commands.append(command); return result(command) }, reader: { _, _ in fixture })
        #expect(commands.count == 1 && commands[0].defaultTimeoutSeconds == 12 && commands[0].arguments.contains("--no-recurse"))
        #expect(output.count == 1 && !output.recursive && !output.businessReadinessVerified)
        #expect(output.entries[0].kind == "non-directory" && output.entries[0].token.hasPrefix("file:"))
        #expect(output.entries[0].name == (sensitive ? "Secret.ips" : nil))
        let text = try encodeJSON(output)
        for secret in ["CORE-PRIVATE", "STALE-ALIAS", "SECRET-STDOUT", "SECRET-STDERR", "SECRET-XATTR", "ownerUid", "isWritable", "UNTRUSTED"] { #expect(!text.contains(secret)) }
        if !sensitive { #expect(!text.contains("Secret.ips")) }
        let baseline = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in fixture })
        #expect(baseline.entries[0].token == output.entries[0].token)
    }
    @Test("physical aliases cannot validate another file record and domain is bound", arguments: ["OTHER", "STALE-ALIAS"])
    func identityMismatch(identifier: String) throws {
        let changed = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "CORE-PRIVATE", with: identifier).utf8)
        #expect(throws: HostDeviceFilesError.identityMismatch) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: TKDevicectlFilesRequest(domain: "systemCrashLogs"), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in changed }) }
    }
    @Test("domain mismatch and recursion are not accepted")
    func mismatchedShape() throws {
        for (old, new, expected) in [("systemCrashLogs", "appDataContainer", HostDeviceFilesError.domainMismatch), ("\"relativePath\":\"Secret.ips\"", "\"relativePath\":\"nested/Secret.ips\"", .invalidJSON)] {
            let changed = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: old, with: new).utf8)
            #expect(throws: expected) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: TKDevicectlFilesRequest(domain: "systemCrashLogs"), artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in changed }) }
        }
    }
    @Test("nonzero returned/thrown restrictions fail without fallback or partial success", arguments: [false, true])
    func restriction(thrown: Bool) throws {
        var calls = 0
        #expect(throws: HostDeviceFilesError.queryUnsupported) {
            _ = try makeIOSDeviceFilesOutput(selection: selection(), request: TKDevicectlFilesRequest(domain: "systemCrashLogs"), artifactProvider: artifacts, runner: { command in
                calls += 1
                if thrown { throw HostCommandRunError.nonZeroExit(command: command, result: result(command, exit: 1)) }
                return result(command, exit: 1)
            }, reader: { _, _ in failed })
        }
        #expect(calls == 1)
    }
    @Test("app identifier is bound to JSON result or exact echoed request, never guessed")
    func appDomainBinding() throws {
        let request = try TKDevicectlFilesRequest(domain: "appDataContainer", domainIdentifier: "secret.bundle")
        let app = String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "systemCrashLogs", with: "appDataContainer")
        for mode in 0...3 {
            let header = mode == 0 ? #""info":{"arguments":["--domain-identifier","secret.bundle"]},"# : (mode == 1 ? #""info":{"arguments":["--domain-identifier","other.bundle"]},"# : "")
            let body = app.replacingOccurrences(of: "{\"result\":", with: "{" + header + "\"result\":")
            let data = Data((mode == 3 ? body.replacingOccurrences(of: "\"files\":", with: "\"domainIdentifier\":\"secret.bundle\",\"files\":") : body).utf8)
            if mode == 1 || mode == 2 {
                #expect(throws: HostDeviceFilesError.domainMismatch) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in data }) }
            } else {
                let output = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in data })
                let encoded = try encodeJSON(output)
                for secret in ["secret.bundle", "private-user", "Library", "Secret.ips"] { #expect(!encoded.contains(secret)) }
            }
        }
    }
    @Test("requested folder/user cannot validate a stale snapshot from another query", arguments: ["--subdirectory", "--username"])
    func queryBinding(flag: String) throws {
        let request = try TKDevicectlFilesRequest(domain: "systemCrashLogs", subdirectory: flag == "--subdirectory" ? "Folder" : nil, username: flag == "--username" ? "user" : nil)
        for header in ["", "\"info\":{\"arguments\":[\"" + flag + "\",\"OTHER\"]},"] {
            let changed = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "{\"result\":", with: "{" + header + "\"result\":").utf8)
            #expect(throws: HostDeviceFilesError.domainMismatch) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in changed }) }
        }
    }
    @Test("missing/invalid JSON, ordinary failure and timeout remain failures with no stdout parsing")
    func failedQueries() throws {
        let request = try TKDevicectlFilesRequest(domain: "systemCrashLogs")
        #expect(throws: HostDeviceFilesError.jsonMissing) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in throw CocoaError(.fileReadNoSuchFile) }) }
        #expect(throws: HostDeviceFilesError.invalidJSON) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in Data("invalid".utf8) }) }
        #expect(throws: HostDeviceFilesError.queryFailed) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0, exit: 1) }, reader: { _, _ in fixture }) }
        #expect(throws: HostDeviceFilesError.timeout) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { command in throw HostCommandRunError.timeout(command: command, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil) }, reader: { _, _ in Issue.record("No JSON read on timeout"); return fixture }) }
    }
    @Test("limit recovery is inspection/replanning, not file write permission")
    func limitRecovery() {
        #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "device_files_limit_exceeded") == ["diagnose", "plan"])
    }
    @Test("bounded readers and injected oversized JSON cannot publish a snapshot")
    func bounds() throws {
        #expect(throws: HostDeviceFilesError.limitExceeded) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: TKDevicectlFilesRequest(domain: "systemCrashLogs"), maximumJSONBytes: 1, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in fixture }) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = root.appendingPathComponent("result.json")
        try fixture.write(to: file)
        #expect(try readBoundedDeviceFilesJSON(file.path, maximumBytes: fixture.count) == fixture)
        #expect(throws: HostDeviceFilesError.limitExceeded) { _ = try readBoundedDeviceFilesJSON(file.path, maximumBytes: 1) }
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        #expect(throws: HostDeviceFilesError.jsonMissing) { _ = try readBoundedDeviceFilesJSON(link.path, maximumBytes: fixture.count) }
        let parentLink = root.appendingPathComponent("parent-link")
        try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: root)
        #expect(throws: HostDeviceFilesError.jsonMissing) { _ = try readBoundedDeviceFilesJSON(parentLink.appendingPathComponent("result.json").path, maximumBytes: fixture.count) }
        let directory = root.appendingPathComponent("not-regular.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        #expect(throws: HostDeviceFilesError.jsonMissing) { _ = try readBoundedDeviceFilesJSON(directory.path, maximumBytes: fixture.count) }
        // Keep tiny task-owned temporary fixture; no broad cleanup or shared-state deletion.
    }
    @Test("invalid limits or platform fail before artifacts/backend")
    func preflight() throws {
        #expect(throws: HostDeviceFilesError.unsupportedPlatform) { _ = try makeIOSDeviceFilesOutput(selection: selection(platform: .android), request: TKDevicectlFilesRequest(domain: "systemCrashLogs"), artifactProvider: { _ in Issue.record("No artifacts"); return ("", "") }) }
        for (bytes, entries, timeout) in [(0, 1, 1.0), (1, 0, 1.0), (16_777_217, 1, 1.0), (1, 1, Double.nan), (1, 1, -1.0)] {
            #expect(throws: HostDeviceSelectionError.self) { _ = try makeIOSDeviceFilesOutput(selection: selection(), request: TKDevicectlFilesRequest(domain: "systemCrashLogs"), timeout: timeout, maximumJSONBytes: bytes, maximumEntries: entries, artifactProvider: { _ in Issue.record("No artifacts"); return ("", "") }) }
        }
    }
    @Test("correctly bound scoped query remains successful and source operands stay private")
    func boundScope() throws {
        let request = try TKDevicectlFilesRequest(domain: "systemCrashLogs", subdirectory: "Folder", username: "private-user")
        let header = #""info":{"arguments":["--device","CORE-PRIVATE","--domain-type","systemCrashLogs","--subdirectory","Folder","--username","private-user","--no-recurse"]},"#
        let data = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "{\"result\":", with: "{" + header + "\"result\":").utf8)
        let output = try makeIOSDeviceFilesOutput(selection: selection(), request: request, artifactProvider: artifacts, runner: { result($0) }, reader: { _, _ in data })
        #expect(output.count == 1)
        let encoded = try encodeJSON(output)
        for secret in ["CORE-PRIVATE", "Folder", "private-user", "Secret.ips"] { #expect(!encoded.contains(secret)) }
    }
    @Test("files has machine discovery and a structured metadata-only output contract")
    func schema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form.hasPrefix("files ") })
        #expect(schema.outputContracts.contains { $0.selector == "host.device-files" })
        #expect(schema.failureCodes.contains("unsupported_device_file_query"))
    }
}
