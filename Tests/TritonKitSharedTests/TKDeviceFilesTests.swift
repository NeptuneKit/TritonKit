import Foundation
import Testing
import TritonKitShared

@Suite("Device Hub file metadata protocol")
struct TKDeviceFilesTests {
    let fixture = Data(#"{"info":{"outcome":"success","commandType":"devicectl.device.info.files"},"result":{"deviceIdentifier":"CORE-PRIVATE","domain":"systemCrashLogs","files":[{"name":"Secret.ips","relativePath":"Secret.ips","metadata":{"size":42,"lastModDate":"2026-10-09T01:00:00.000Z","ownerUid":501,"extendedAttributes":{"secret":"HIDDEN"}},"resources":{"isDirectory":false,"isSymbolicLink":false,"isReadable":true,"isWritable":true}}]}}"#.utf8)
    @Test("actual anonymous metadata shape is parsed without promoting non-directory to regular file")
    func actualShape() throws {
        let payload = try TKDevicectlFilesParser.parse(fixture)
        #expect(payload.deviceIdentifier == "CORE-PRIVATE" && payload.domain == "systemCrashLogs")
        #expect(payload.files.count == 1 && payload.files[0].sizeBytes == 42)
        #expect(payload.files[0].kind == "non-directory")
    }
    @Test("strict types, traversal and failed/contradictory envelopes fail closed", arguments: [
        ("\"size\":42", "\"size\":true"), ("\"size\":42", "\"size\":-1"), ("\"size\":42", "\"size\":18446744073709551616"),
        ("\"isDirectory\":false", "\"isDirectory\":1"), ("\"isSymbolicLink\":false", "\"isSymbolicLink\":null"),
        ("\"relativePath\":\"Secret.ips\"", "\"relativePath\":\"../Secret.ips\""),
        ("\"outcome\":\"success\"", "\"outcome\":\"failed\""), ("\"info\":", "\"error\":{\"code\":1},\"info\":"),
        ("devicectl.device.info.files", "devicectl.device.copy.to"),
        ("2026-10-09T01:00:00.000Z", "SECRET-DATE")
    ])
    func malformed(input: (String, String)) {
        let changed = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: input.0, with: input.1).utf8)
        #expect(throws: TKDevicectlFilesError.malformedJSON) { _ = try TKDevicectlFilesParser.parse(changed) }
    }
    @Test("only the exact structured listFiles rejection is unsupported")
    func unsupported() {
        let failed = #"{"info":{"outcome":"failed"},"error":{"code":1001,"domain":"com.apple.dt.CoreDeviceError","userInfo":{"CapabilityFeatureIdentifier":{"string":"com.apple.coredevice.feature.listFiles"}}}}"#
        #expect(TKDevicectlFilesParser.isUnsupported(Data(failed.utf8)))
        for (old, new) in [("1001", "1002"), ("failed", "success"), ("listFiles", "getlockstate"), ("com.apple.dt.CoreDeviceError", "other")] {
            #expect(!TKDevicectlFilesParser.isUnsupported(Data(failed.replacingOccurrences(of: old, with: new).utf8)))
        }
    }
    @Test("byte and entry limits reject acceptance, not silently truncate")
    func limits() {
        #expect(throws: TKDevicectlFilesError.limitExceeded) { _ = try TKDevicectlFilesParser.parse(fixture, maximumJSONBytes: 1) }
        #expect(throws: TKDevicectlFilesError.limitExceeded) { _ = try TKDevicectlFilesParser.parse(fixture, maximumEntries: 0) }
    }
    @Test("invalid domain/path/username requests fail before building argv", arguments: [
        ("temporary", "space", "."), ("appDataContainer", "", "."), ("systemCrashLogs", "bundle", "."),
        ("systemCrashLogs", "", "/etc"), ("systemCrashLogs", "", "../escape"), ("systemCrashLogs", "", "a/../b"),
        ("systemCrashLogs", "", "a//b"), ("systemCrashLogs", "", "a\npath")
    ])
    func requestErrors(input: (String, String, String)) {
        #expect(throws: (any Error).self) { _ = try TKDevicectlFilesRequest(domain: input.0, domainIdentifier: input.1.isEmpty ? nil : input.1, subdirectory: input.2) }
    }
    @Test("shallow file command uses username, not copy user, and marks all private operands")
    func argv() throws {
        let request = try TKDevicectlFilesRequest(domain: "appGroupDataContainer", domainIdentifier: "group.secret", subdirectory: "Folder Name", username: "private-user")
        let command = TKDevicectlCommand.deviceInfoFiles(identifier: "CORE-PRIVATE", request: request, jsonOutput: "/private/result.json", logOutput: "/private/log")
        #expect(command.arguments.prefix(6) == ["devicectl", "device", "info", "files", "--device", "CORE-PRIVATE"])
        #expect(command.arguments.contains("--no-recurse") && command.arguments.contains("--username"))
        #expect(!command.arguments.contains("--user") && !command.arguments.contains("--remove-existing-content"))
        #expect(command.riskLevel == .readonly && command.sensitiveOutput)
        for secret in ["CORE-PRIVATE", "group.secret", "Folder Name", "private-user"] {
            #expect(command.redactedArgumentIndexes.contains(try #require(command.arguments.firstIndex(of: secret))))
        }
    }
}
