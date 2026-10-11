import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("DeviceFS native mount requires explicit policy and durable audit")
struct DeviceMountPolicyTests {
    private let policy = HostDeviceMountPolicy(allowMount: true, confirm: true, executeRunner: true, auditRecord: "fixture-mount-intent")
    private func fixtureDirectory() throws -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().appendingPathComponent(".triton-mount-fixture-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return root
    }
    @Test func allPolicyFieldsRequiredBeforeDiscoveryOrArtifacts() throws {
        for policy in [HostDeviceMountPolicy(), HostDeviceMountPolicy(allowMount: true), HostDeviceMountPolicy(allowMount: true, confirm: true, executeRunner: true), HostDeviceMountPolicy(allowMount: true, confirm: true, executeRunner: true, auditRecord: "\n")] {
            #expect(throws: HostDeviceMountPolicyError.required) { try policy.validate() }
            var touched = false
            #expect(throws: HostDeviceMountPolicyError.required) {
                _ = try resolveAuthorizedMountpointSelection(policy: policy, request: HostDeviceSelectionRequest(platform: .ios), resolver: { _ in touched = true; throw HostDeviceMountpointError.queryFailed })
            }
            #expect(!touched)
        }
        try policy.validate()
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "fixture-private", state: "unknown", ready: false, blockedReasons: []))
        let selection = HostDeviceSelectionResult(platform: .ios, target: target, selector: target.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
        var touched = false
        #expect(throws: HostDeviceMountPolicyError.required) {
            _ = try makeIOSDeviceMountpointOutput(selection: selection, artifactProvider: { _ in touched = true; return ("", "") })
        }
        #expect(throws: HostDeviceMountPolicyError.required) {
            _ = try makeIOSDeviceFSListOutput(selection: selection, artifactProvider: { _ in touched = true; return ("", "") })
        }
        #expect(!touched)
    }
    @Test func durableIntentPrecedesNativeAndCreationRemainsUnknown() throws {
        let directory = try fixtureDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let value: Int = try withDeviceMountAudit(policy: policy, action: "device.fs.list", target: "redacted-fixture", workspace: { directory.path }) { audit in
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("intent.json").path))
            try audit.beforeNativeExecution()
            return 7
        }
        #expect(value == 7)
        let completion = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("completion.json"))) as? [String: Any])
        #expect(completion["status"] as? String == "metadata-accepted")
        #expect(completion["mountCreated"] as? String == "unknown")
        #expect(completion["contentsRead"] as? Bool == false)
        var st = stat(); #expect(lstat(directory.appendingPathComponent("completion.json").path, &st) == 0 && st.st_mode & 0o777 == 0o600)
    }
    @Test func replacedWorkspaceNeverReceivesSuccessAndCauseIsAudited() throws {
        let directory = try fixtureDirectory(); let moved = directory.appendingPathExtension("moved")
        defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: moved) }
        do {
            let _: Int = try withDeviceMountAudit(policy: policy, action: "device.mountpoint", target: "redacted-fixture", workspace: { directory.path }) { audit in
                try audit.beforeNativeExecution()
                try FileManager.default.moveItem(at: directory, to: moved)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                return 1
            }
            Issue.record("Replaced audit workspace must not return success")
        } catch let failure as HostDeviceMountExecutionFailure {
            #expect(failure.status == "uncertain" && !failure.auditToken.isEmpty)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("completion.json").path))
        let completion = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: moved.appendingPathComponent("completion.json"))) as? [String: Any])
        #expect(completion["status"] as? String == "uncertain" && completion["mountCreated"] as? String == "unknown")
    }
    @Test func listingFailureKeepsOriginalCodeAndAuditToken() throws {
        let directory = try fixtureDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let _: Int = try withDeviceMountAudit(policy: policy, action: "device.fs.list", target: "redacted-fixture", workspace: { directory.path }) { audit in
                try audit.beforeNativeExecution()
                throw HostDeviceFSError.limitExceeded
            }
            Issue.record("Expected failed listing")
        } catch let failure as HostDeviceMountExecutionFailure {
            #expect(failure.detail.code == "device_fs_limit_exceeded")
            #expect(failure.detail.hint?.contains(failure.auditToken) == true)
            #expect(failure.status == "uncertain")
        }
    }
    @Test func strictNativeReceiptRejectsMissingChangedArgumentsOutcomeAndError() throws {
        let command = TKDevicectlCommand.deviceInfoMountpoint(identifier: "fixture", jsonOutput: "/private/fixture.json", logOutput: "/private/fixture.log")
        let valid: [String: Any] = ["info": ["arguments": command.arguments, "outcome": "success", "commandType": "devicectl.device.info.mountpoint"], "result": ["dataPath": "/private/fixture"]]
        try validateDeviceMountReceipt(JSONSerialization.data(withJSONObject: valid), command: command)
        for patch in [["info": ["arguments": [], "outcome": "success", "commandType": "devicectl.device.info.mountpoint"]], ["info": ["arguments": command.arguments, "outcome": "failed", "commandType": "devicectl.device.info.mountpoint"]], ["error": ["code": 1]]] as [[String: Any]] {
            var root = valid; root.merge(patch) { _, newer in newer }
            #expect(throws: HostDeviceMountpointError.invalidJSON) { try validateDeviceMountReceipt(JSONSerialization.data(withJSONObject: root), command: command) }
        }
    }
}
