import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Temporary files explicit possible-creation policy")
struct TemporaryDomainPolicyTests {
    @Test func temporaryExecutionIsAuditedAndNeverReadonly() throws {
        let directory = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().appendingPathComponent(".triton-temporary-fixture-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: "PRIVATE-FIXTURE", state: "blocked", ready: false, blockedReasons: []))
        let selection = HostDeviceSelectionResult(platform: .ios, target: target, selector: "fixture", source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
        let request = try TKDevicectlFilesRequest(domain: "temporary", domainIdentifier: "fixture-domain", allowTemporaryCreation: true)
        var touched = false
        #expect(throws: TKDevicectlFilesError.temporaryRequiresPolicy) {
            _ = try makeIOSDeviceFilesOutput(selection: selection, request: request, artifactProvider: { _ in touched = true; return ("/fixture", "/fixture-log") })
        }
        #expect(!touched)
        var native: TKHostCommand?
        let policy = HostTemporaryDomainPolicy(allowDomainCreation: true, confirm: true, executeRunner: true, auditRecord: "fixture-audit")
        let output = try makeIOSDeviceFilesOutput(selection: selection, request: request, temporaryPolicy: policy, temporaryWorkspaceProvider: { directory.path }, artifactProvider: { _ in (directory.appendingPathComponent("query.json").path, directory.appendingPathComponent("query.log").path) }, runner: { command in
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("intent.json").path))
            #expect(command.riskLevel == .automation)
            #expect(command.requiredConfig.contains(.auditRecord))
            native = command
            return HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: hostSourceCommand(command), stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
        }, reader: { _, _ in
            let command = try #require(native)
            return try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success", "commandType": "devicectl.device.info.files", "arguments": command.arguments], "result": ["deviceIdentifier": "PRIVATE-FIXTURE", "domain": "temporary", "domainIdentifier": "fixture-domain", "files": []]])
        })
        #expect(output.riskLevel == "automation")
        #expect(output.auditToken != nil && output.temporaryDomainPolicy != nil)
        let completion = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("completion.json"))) as? [String: Any])
        #expect(completion["created"] as? String == "unknown")
        #expect((completion["artifacts"] as? [String])?.count == 2)
        let encoded = String(decoding: try JSONEncoder().encode(output), as: UTF8.self)
        #expect(!encoded.contains("fixture-domain") && !encoded.contains("PRIVATE-FIXTURE"))
    }
    @Test func workspaceReplacementCannotSplitIntentAndSuccessfulCompletion() throws {
        let root = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().appendingPathComponent(".triton-audit-replacement-" + UUID().uuidString)
        let moved = root.appendingPathExtension("moved")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: moved) }
        let policy = HostTemporaryDomainPolicy(allowDomainCreation: true, confirm: true, executeRunner: true, auditRecord: "fixture")
        #expect(throws: HostTemporaryDomainFailure.self) {
            let _: Int = try withTemporaryDomainAudit(policy: policy, target: "redacted", domainIdentifier: "fixture", workspace: { root.path }, operation: { _ in
                try FileManager.default.moveItem(at: root, to: moved)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                return 1
            })
        }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("completion.json").path))
        #expect(FileManager.default.fileExists(atPath: moved.appendingPathComponent("intent.json").path))
        let completionURL = moved.appendingPathComponent("completion.json")
        #expect(FileManager.default.fileExists(atPath: completionURL.path))
        if FileManager.default.fileExists(atPath: completionURL.path) {
            let completion = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: completionURL)) as? [String: Any])
            #expect(completion["status"] as? String == "uncertain")
        }
    }
    @Test func requiresExactExecutionReceipt() throws {
        let command = TKHostCommand(arguments: ["devicectl", "device", "info", "files", "--device", "fixture"])
        let valid: [String: Any] = ["info": ["arguments": command.arguments, "outcome": "success", "commandType": "devicectl.device.info.files"], "result": [:]]
        try validateTemporaryFilesReceipt(JSONSerialization.data(withJSONObject: valid), command: command)
        for invalid in [["result": [:]], ["info": ["arguments": [], "outcome": "success", "commandType": "devicectl.device.info.files"]], ["info": ["arguments": command.arguments, "outcome": "failed", "commandType": "devicectl.device.info.files"]]] as [[String: Any]] {
            #expect(throws: (any Error).self) { try validateTemporaryFilesReceipt(JSONSerialization.data(withJSONObject: invalid), command: command) }
        }
    }
    @Test func policyRequiresAllFlags() throws {
        for p in [HostTemporaryDomainPolicy(), HostTemporaryDomainPolicy(allowDomainCreation: true), HostTemporaryDomainPolicy(allowDomainCreation: true, confirm: true, executeRunner: true)] {
            #expect(throws: (any Error).self) { try p.validate() }
        }
        try HostTemporaryDomainPolicy(allowDomainCreation: true, confirm: true, executeRunner: true, auditRecord: "fixture").validate()
        #expect(throws: (any Error).self) { try HostTemporaryDomainPolicy(allowDomainCreation: true, confirm: true, executeRunner: true, auditRecord: "\n").validate() }
    }
    @Test func auditPrecedesActionAndRecordsUncertainty() throws {
        let p = HostTemporaryDomainPolicy(allowDomainCreation: true, confirm: true, executeRunner: true, auditRecord: "fixture")
        var events: [String] = []
        #expect(throws: (any Error).self) {
            let _: Int = try withTemporaryDomainAudit(policy: p, target: "redacted", domainIdentifier: "fixture", workspace: { "/fixture" }, persist: { value, _, name in
                events.append(name)
                if name == "completion.json" { #expect(value["status"] as? String == "uncertain") }
            }, operation: { _ in events.append("action"); throw HostDeviceFilesError.timeout })
        }
        #expect(events == ["intent.json", "action", "completion.json"])
        events = []
        #expect(throws: (any Error).self) {
            let _: Int = try withTemporaryDomainAudit(policy: p, target: "redacted", domainIdentifier: "fixture", workspace: { "/fixture" }, persist: { _, _, _ in throw HostDeviceAdministrationError.auditFailed }, operation: { _ in events.append("action"); return 1 })
        }
        #expect(events.isEmpty)
    }
}
