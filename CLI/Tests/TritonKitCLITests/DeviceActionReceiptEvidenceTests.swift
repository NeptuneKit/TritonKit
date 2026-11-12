import ArgumentParser
import CryptoKit
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("SP-281 production action receipts and evidence", .serialized)
struct DeviceActionReceiptEvidenceTests {
    private func press(_ extra: [String] = []) throws -> DevicePress {
        let parsed = try TritonKitCLI.parseAsRoot(["device", "press", "--device", "android:fixture", "--platform", "android", "--button", "home", "--request-id", "receipt-test"] + extra)
        return try #require(parsed as? DevicePress)
    }
    private var target: HostDeviceTarget {
        HostDeviceTarget(platform: "android", id: "android:fixture", target: "fixture", state: "ready", ready: true, source: "fixture", name: nil, runtime: nil, transport: "adb", scope: "emulator")
    }
    private func process(_ exit: Int32 = 0) -> HostProcessResult {
        HostProcessResult(stdoutData: Data("PRIVATE-provider-output".utf8), stderrData: Data("PRIVATE-error".utf8), exitCode: exit, sourceCommand: "/private/source-command", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 23, stderrBytes: 13)
    }
    private func object(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("nonzero returned results cannot become successful action receipts")
    func returnedNonzero() async throws {
        let command = try press()
        var calls = 0
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in calls += 1; return process(7) })
        let json = try object(output)
        #expect(calls == 1)
        #expect(json["ok"] as? Bool == false)
        let receipt = try #require(json["actionReceipt"] as? [String: Any])
        #expect(receipt["actionID"] as? String == "receipt-test")
        #expect(receipt["delivery"] as? String == "unknown")
        #expect(receipt["outcome"] as? String == "uncertain")
        #expect(receipt["executed"] == nil || receipt["executed"] is NSNull)
    }

    @Test("timeout returns a bound unknown receipt and never repeats input")
    func timeoutReceipt() async throws {
        let command = try press()
        var calls = 0
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { issued in
            calls += 1
            throw HostCommandRunError.timeout(command: issued, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil)
        })
        let json = try object(output)
        #expect(calls == 1)
        #expect(json["ok"] as? Bool == false)
        #expect(json["delivery"] as? String == "unknown")
        let receipt = try #require(json["actionReceipt"] as? [String: Any])
        #expect(receipt["failureCode"] as? String == "host_command_timeout")
        #expect(receipt["admissionID"] as? String != nil)
    }

    @Test("explicit evidence preserves provider output alongside a parseable typed run")
    func writtenEvidence() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let outputDir = parent.appendingPathComponent("action.tritonevidence")
        let command = try press(["--evidence-dir", outputDir.path])
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in process() })
        let json = try object(output)
        #expect(json["evidencePersistence"] as? String == "written")
        let events = try TKEvidenceRunLogParser().parse(Data(contentsOf: outputDir.appendingPathComponent("run/events.jsonl")))
        #expect(events.status == .completed)
        #expect(events.events.compactMap(\.actionContext).last?.actionID == "receipt-test")
        let artifact = try Data(contentsOf: outputDir.appendingPathComponent("run/action-receipt.json"))
        let receipt = try JSONDecoder().decode(TKActionReceipt.self, from: artifact)
        try receipt.validate()
        #expect(receipt.evidencePersistence == .written)
        #expect(!String(decoding: artifact, as: UTF8.self).contains("PRIVATE"))
        #expect(!String(decoding: artifact, as: UTF8.self).contains("source-command"))
        let manifest = try JSONDecoder().decode(TKEvidenceManifest.self, from: Data(contentsOf: outputDir.appendingPathComponent("manifest.json")))
        #expect(manifest.ok && !manifest.partial)
        #expect(manifest.run?.eventCount == 6)
        #expect(manifest.artifacts.count == 6)
        #expect(try Data(contentsOf: outputDir.appendingPathComponent("run/provider-1-stdout.bin")) == process().stdoutData)
        #expect(try Data(contentsOf: outputDir.appendingPathComponent("run/provider-1-stderr.bin")) == process().stderrData)
        let response = try object(Data(contentsOf: outputDir.appendingPathComponent("run/provider-response.json")))
        #expect(response["sourceCommand"] as? String == process().sourceCommand)
        for artifact in manifest.artifacts {
            let data = try Data(contentsOf: outputDir.appendingPathComponent(artifact.path))
            #expect(artifact.bytes == data.count)
            #expect(artifact.metadata?["sha256"] == .string(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()))
        }
    }

    @Test("existing evidence roots reject before provider execution")
    func existingEvidenceIsNotOverwritten() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-existing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sentinel = root.appendingPathComponent("keep")
        try Data("original".utf8).write(to: sentinel)
        let command = try press(["--evidence-dir", root.path])
        var calls = 0
        do {
            _ = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in calls += 1; return process() })
            Issue.record("Existing evidence root unexpectedly accepted")
        } catch { }
        #expect(calls == 0)
        #expect(try Data(contentsOf: sentinel) == Data("original".utf8))
    }
    @Test("second double-tap launch failure remains unknown after first input")
    func partialDoubleTap() async throws {
        let parsed = try TritonKitCLI.parseAsRoot(["device", "double-tap", "--device", "android:fixture", "--platform", "android",
            "--x", "1", "--y", "2", "--width", "100", "--height", "200", "--orientation", "portrait", "--observation-id", "o"])
        let command = try #require(parsed as? DeviceDoubleTap)
        var calls = 0
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in
            calls += 1
            if calls == 2 { throw HostCommandRunError.launchFailed("PRIVATE") }
            return process()
        })
        let json = try object(output)
        #expect(calls == 2)
        #expect(json["ok"] as? Bool == false)
        #expect(json["delivery"] as? String == "unknown")
        #expect(json["executed"] is NSNull)
        #expect(!String(decoding: output, as: UTF8.self).contains("PRIVATE"))
    }

    @Test("first launch failure is not-started and cannot claim delivery")
    func firstLaunchFailure() async throws {
        let command = try press()
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in
            throw HostCommandRunError.launchFailed("PRIVATE")
        })
        let json = try object(output)
        #expect(json["delivery"] as? String == "not_started")
        #expect(json["executed"] as? Bool == false)
    }

    @Test("nested and contradictory iOS errors never pass the command success predicate")
    func contradictoryEnvelopes() async throws {
        let parsed = try TritonKitCLI.parseAsRoot(["device", "press", "--device", "sim:fixture", "--platform", "ios",
            "--button", "home", "--bundle-id", "fixture.app", "--session-root", "/private/sentinel"])
        let command = try #require(parsed as? DevicePress)
        let iosTarget = HostDeviceTarget(platform: "ios", id: "sim:fixture", target: "fixture", state: "ready", ready: true,
            source: "fixture", name: nil, runtime: nil, transport: "fixture", scope: "simulator")
        for response: [String: Any] in [
            ["ok": true, "result": ["ok": false, "error": ["code": "ios_runner_transport_unknown", "message": "PRIVATE"], "executed": true]],
            ["ok": true, "result": ["executed": false, "postconditionVerified": true]],
            ["ok": true, "result": ["status": "uncertain", "submitted": true, "executed": true]],
            ["ok": true, "result": ["status": "blocked", "executed": true]],
            ["ok": true, "result": ["outcome": "not_started", "postconditionVerified": true]]
        ] {
            let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in iosTarget },
                iosRunner: { _ in try JSONSerialization.data(withJSONObject: response) })
            let json = try object(output)
            #expect(json["ok"] as? Bool == false)
            #expect(json["delivery"] as? String == "unknown")
            #expect(json["executed"] is NSNull)
        }
    }

    @Test("evidence failure preserves delivered facts and does not publish a manifest")
    func evidenceFailureKeepsProviderFacts() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-failure-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("failed.tritonevidence")
        let command = try press(["--evidence-dir", root.path])
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in
            try Data("sentinel".utf8).write(to: root.appendingPathComponent("run/action-receipt.json"))
            return process()
        })
        let json = try object(output)
        #expect(json["ok"] as? Bool == true)
        #expect(json["delivery"] as? String == "delivered")
        #expect(json["evidencePersistence"] as? String == "failed")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))
        #expect(try Data(contentsOf: root.appendingPathComponent("run/action-receipt.json")) == Data("sentinel".utf8))
    }

    @Test("evidence refuses parent symlinks without touching destination")
    func symlinkParentIsRejected() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let real = parent.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = parent.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let command = try press(["--evidence-dir", link.appendingPathComponent("out").path])
        var calls = 0
        do {
            _ = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in calls += 1; return process() })
            Issue.record("Symlink parent unexpectedly followed")
        } catch { }
        #expect(calls == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: real.path).isEmpty)
    }

    @Test("real HTTP lease conflict keeps its original diagnostics with evidence")
    func httpLeaseConflictEvidence() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-http-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("blocked.tritonevidence")
        let command = try press(["--lease", "lease-other", "--evidence-dir", root.path])
        let envelope = try JSONSerialization.data(withJSONObject: ["ok": false,
            "error": ["code": "target_lease_conflict", "message": "held", "currentOwner": "other", "leaseReason": "held_by_other"]])
        var calls = 0
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in
            calls += 1; return process()
        }, leaseGate: { throw CLIHTTPError(statusCode: 409, data: envelope) })
        let json = try object(output)
        #expect(calls == 0)
        #expect((json["error"] as? [String: Any])?["currentOwner"] as? String == "other")
        #expect((json["actionReceipt"] as? [String: Any])?["failureCode"] as? String == "target_lease_conflict")
        let receipt = try JSONDecoder().decode(TKActionReceipt.self, from: Data(contentsOf: root.appendingPathComponent("run/action-receipt.json")))
        #expect(receipt.delivery == .notStarted && receipt.executed == false)
        #expect(receipt.admissionID == nil)
    }

    @Test("partial manifest collision preserves the caller file and fails persistence")
    func manifestCannotBeReplaced() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-manifest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("out.tritonevidence")
        let command = try press(["--evidence-dir", root.path])
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in
            try Data("sentinel".utf8).write(to: root.appendingPathComponent("manifest.json"))
            return process()
        })
        #expect(try object(output)["evidencePersistence"] as? String == "failed")
        #expect(try Data(contentsOf: root.appendingPathComponent("manifest.json")) == Data("sentinel".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".manifest-") })
    }

    @Test("CLI emits one JSON object then fails for uncertainty or requested evidence failure")
    func singleEnvelopeAndFailureExit() throws {
        for payload: [String: Any] in [["ok": false, "outcome": "uncertain"], ["ok": true, "delivery": "delivered", "evidencePersistence": "failed"]] {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-stdout-\(UUID().uuidString)")
            FileManager.default.createFile(atPath: file.path, contents: nil)
            defer { try? FileManager.default.removeItem(at: file) }
            let handle = try FileHandle(forWritingTo: file)
            fflush(stdout)
            let original = dup(STDOUT_FILENO)
            #expect(original >= 0)
            dup2(handle.fileDescriptor, STDOUT_FILENO)
            var failure: Error?
            do { try emitDeviceActionOutput(JSONSerialization.data(withJSONObject: payload)) } catch { failure = error }
            fflush(stdout)
            dup2(original, STDOUT_FILENO); close(original); try handle.close()
            #expect(failure as? ExitCode == .failure)
            let decoded = try object(Data(contentsOf: file))
            #expect(decoded["ok"] as? Bool == payload["ok"] as? Bool)
        }
    }

    @Test("exported evidence records audit failure without erasing verified input")
    func auditFailureIsNotEvidenceSuccess() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sp281-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let args = try TKActionArgumentsDigest.make(arguments: ["button": .string("home")])
        let context = TKActionContext(actionID: "audit-1", target: "sim:fixture", operation: "device.platform-control",
            argsDigest: args.digest, createdAt: "2026-11-11T00:00:00Z")
        let root = parent.appendingPathComponent("audit.tritonevidence")
        let session = try ActionEvidenceSession(directory: root.path, context: context, platform: "ios")
        let original = TKActionReceipt(actionID: context.actionID, operation: context.operation, target: context.target,
            delivery: .delivered, outcome: .settled, executed: true, originalStatus: "executed", terminalStatus: "runner_audit_failed",
            postcondition: .verified, evidencePersistence: .failed, failureCode: "runner_audit_failed")
        let written = session.finish(original)
        #expect(written.failureCode == "runner_audit_failed")
        #expect(written.delivery == .delivered && written.postcondition == .verified)
        let run = try TKEvidenceRunLogParser().parse(Data(contentsOf: root.appendingPathComponent("run/events.jsonl")))
        #expect(run.summary.verdict == .failure)
        #expect(run.events.first(where: { $0.kind == .toolResult })?.success == false)
    }

    @Test("untrusted status text cannot leak into shared receipt or produce success")
    func statusTextIsNotReceiptMetadata() throws {
        let command = try press()
        let (context, digest) = try makeDeviceActionContext(command.payload(), selected: target, leaseID: nil)
        let provider = try JSONSerialization.data(withJSONObject: ["ok": true, "status": "/private/PRIVATE-input", "executed": true])
        let receipt = try deviceActionReceipt(provider, context: context, contextDigest: digest, admissionID: "admitted")
        #expect(receipt.outcome == .uncertain && receipt.executed == nil)
        #expect(!String(decoding: try JSONEncoder().encode(receipt), as: UTF8.self).contains("PRIVATE"))
    }

    @Test("provider prefixes cannot masquerade as complete original output")
    func truncatedRawOutputIsPartial() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("raw-prefix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("partial.tritonevidence")
        let command = try press(["--evidence-dir", root.path])
        let data = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { _ in
            HostProcessResult(stdoutData: Data("prefix".utf8), stderrData: Data(), exitCode: 0, sourceCommand: "fixture",
                stdoutTruncated: true, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 100, stderrBytes: 0)
        })
        let json = try object(data)
        #expect(json["delivery"] as? String == "delivered")
        #expect(json["evidencePersistence"] as? String == "partial")
        let manifest = try JSONDecoder().decode(TKEvidenceManifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        #expect(!manifest.ok && manifest.partial)
        let artifact = try #require(manifest.artifacts.first { $0.path == "run/provider-1-stdout.bin" })
        #expect(artifact.metadata?["truncated"] == .bool(true))
        #expect(artifact.metadata?["observedBytes"] == .int(100))
        #expect(artifact.bytes == 6)
        #expect(try Data(contentsOf: root.appendingPathComponent(artifact.path)) == Data("prefix".utf8))
    }

    @Test("timeout output unavailable is recorded rather than invented or called complete")
    func timeoutOutputCoverage() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("raw-timeout-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("timeout.tritonevidence")
        let command = try press(["--evidence-dir", root.path])
        let output = try await executeDeviceAction(command.payload(), common: command.common, targetResolver: { _ in target }, hostRunner: { issued in
            throw HostCommandRunError.timeout(command: issued, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil)
        })
        #expect(try object(output)["delivery"] as? String == "unknown")
        #expect(try object(output)["evidencePersistence"] as? String == "partial")
        let manifest = try JSONDecoder().decode(TKEvidenceManifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        #expect(!manifest.ok && manifest.partial)
        let coverage = try #require(manifest.artifacts.first { $0.path == "run/provider-1-coverage.json" })
        #expect(coverage.metadata?["available"] == .bool(false))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("run/provider-1-stdout.bin").path))
    }

}
