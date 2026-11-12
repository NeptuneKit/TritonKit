import CryptoKit
import Darwin
import Foundation
import TritonKitShared

struct ActionEvidenceFailure: Error {
    let code: String
}

/// Opt-in action evidence owns a freshly claimed root. All writes use retained
/// directory FDs; replacement paths are rejected, never followed. manifest.json
/// is published last and commits the written receipt/events snapshot.
struct ActionRawArtifact {
    let name: String
    let data: Data
    let contentType: String
    var unavailable: Bool = false
    var truncated: Bool = false
    var observedBytes: Int? = nil
    var fidelity: String = "original"
}

final class ActionEvidenceSession {
    let directory: URL
    private let rootFD: Int32
    private let runFD: Int32
    private let device: dev_t
    private let inode: ino_t
    private let context: TKActionContext
    private let platform: String
    private let metadataBytes: Data
    private var events: [TKEvidenceRunEvent] = []
    private var finished = false
    private let lock = NSLock()

    init(directory: String, context: TKActionContext, platform: String) throws {
        guard directory.hasPrefix("/"), !directory.contains("\0") else {
            throw ActionEvidenceFailure(code: "action_evidence_path_invalid")
        }
        // Darwin's system aliases are resolved explicitly, not arbitrary caller links.
        var path = directory
        if path.hasPrefix("/var/") { path = "/private" + path }
        if path.hasPrefix("/tmp/") { path = "/private" + path }
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let leaf = components.last, !components.contains("."), !components.contains("..") else {
            throw ActionEvidenceFailure(code: "action_evidence_path_invalid")
        }
        var parent = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_path_invalid") }
        defer { close(parent) }
        for component in components.dropLast() {
            let next = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_path_invalid") }
            close(parent); parent = next
        }
        guard mkdirat(parent, leaf, 0o700) == 0 else {
            throw ActionEvidenceFailure(code: "action_evidence_root_unavailable")
        }
        let root = openat(parent, leaf, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard root >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_path_invalid") }
        var info = stat()
        guard fstat(root, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0,
              mkdirat(root, "run", 0o700) == 0 else {
            close(root); throw ActionEvidenceFailure(code: "action_evidence_write_failed")
        }
        let run = openat(root, "run", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard run >= 0 else { close(root); throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
        self.directory = URL(fileURLWithPath: path)
        self.rootFD = root; self.runFD = run
        self.device = info.st_dev; self.inode = info.st_ino
        self.context = context; self.platform = platform
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        self.metadataBytes = try encoder.encode(TKEvidenceRunMetadata(runID: context.actionID, caseName: context.operation, createdAt: context.createdAt))
        // Once self is initialized, deinit owns descriptor cleanup even if an
        // initial artifact write throws; do not close the same FDs twice.
        try write(metadataBytes, name: "meta.json", parent: run)
        events = [event(.runStarted), event(.stepStarted), event(.toolCall)]
        try write(try lines(events), name: "events.jsonl", parent: run)
    }

    deinit { close(runFD); close(rootFD) }

    func finish(_ receipt: TKActionReceipt, rawArtifacts: [ActionRawArtifact] = []) -> TKActionReceipt {
        lock.lock(); defer { lock.unlock() }
        guard !finished else { return receipt.recordingEvidence(.failed, refs: []) }
        finished = true
        let refs = ["run/action-receipt.json"] + rawArtifacts.map { "run/" + $0.name }
        let partial = rawArtifacts.contains { $0.truncated || $0.unavailable }
        let stored = receipt.recordingEvidence(partial ? .partial : .written, refs: refs)
        do {
            try verifyIdentity()
            for artifact in rawArtifacts {
                guard !artifact.name.isEmpty, !artifact.name.contains("/"), artifact.name != ".", artifact.name != "..",
                      artifact.name != "action-receipt.json", artifact.name != "meta.json", artifact.name != "events.jsonl" else {
                    throw ActionEvidenceFailure(code: "action_evidence_path_invalid")
                }
                try write(artifact.data, name: artifact.name, parent: runFD)
            }
            let receiptData = try encode(stored)
            try write(receiptData, name: "action-receipt.json", parent: runFD)
            let terminal = [event(.toolResult, receipt: stored), event(.stepCompleted, receipt: stored), event(.runCompleted, receipt: stored)]
            try append(try lines(terminal), name: "events.jsonl", parent: runFD)
            events += terminal
            let eventBytes = try read("events.jsonl", parent: runFD)
            guard eventBytes == (try lines(events)), try read("meta.json", parent: runFD) == metadataBytes else {
                throw ActionEvidenceFailure(code: "action_evidence_write_failed")
            }
            let parsed = try TKEvidenceRunLogParser().parse(eventBytes)
            guard parsed.status == .completed, !parsed.truncatedTail else {
                throw ActionEvidenceFailure(code: "action_evidence_write_failed")
            }
            var artifacts = [("action.receipt", refs[0], receiptData), ("action.events", "run/events.jsonl", eventBytes),
                ("action.metadata", "run/meta.json", metadataBytes)].map { kind, path, data in
                TKEvidenceArtifact(kind: kind, path: path, contentType: path.hasSuffix("jsonl") ? "application/x-ndjson" : "application/json",
                    bytes: data.count, source: "action-receipt", redactionStatus: "schema-whitelist",
                    metadata: ["sha256": .string(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())], target: receipt.target)
            }
            artifacts += rawArtifacts.map { artifact in
                TKEvidenceArtifact(kind: artifact.fidelity == "original" ? "action.provider-raw" : "action.provider-diagnostic", path: "run/" + artifact.name, contentType: artifact.contentType,
                    bytes: artifact.data.count, source: "provider", fidelity: artifact.fidelity, redactionStatus: "none",
                    metadata: ["sha256": .string(SHA256.hash(data: artifact.data).map { String(format: "%02x", $0) }.joined()),
                        "available": .bool(!artifact.unavailable), "truncated": .bool(artifact.truncated), "retainedBytes": .int(artifact.data.count),
                        "observedBytes": artifact.observedBytes.map(TKJSONValue.int) ?? .null], target: receipt.target)
            }
            let manifest = TKEvidenceManifest(ok: !partial, partial: partial,
                error: partial ? TKCLIErrorDetail(code: "action_evidence_partial", message: "Provider output is incomplete: retained prefixes or unavailable streams are explicitly marked.") : nil,
                name: context.operation,
                createdAt: context.createdAt, output: "<evidence-root>", artifacts: artifacts,
                target: TKEvidenceTarget(id: context.target, connected: false, identityState: "action-bound-not-reobserved"),
                cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion),
                run: TKEvidenceRunManifest(eventCount: parsed.events.count, status: parsed.status, summary: parsed.summary))
            try verifyIdentity()
            try commitManifest(try encode(manifest))
            return stored
        } catch {
            return receipt.recordingEvidence(.failed, refs: [])
        }
    }

    private func commitManifest(_ data: Data) throws {
        let temporary = ".manifest-" + UUID().uuidString
        let fd = openat(rootFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
        defer { close(fd); _ = unlinkat(rootFD, temporary, 0) }
        try writeAll(data, fd: fd)
        // Hard-link publication is exclusive and atomic: never replace a caller file.
        guard linkat(rootFD, temporary, rootFD, "manifest.json", 0) == 0 else {
            throw ActionEvidenceFailure(code: "action_evidence_write_failed")
        }
        guard fsync(rootFD) == 0 else {
            // Only withdraw the marker we just published, never another inode.
            var source = stat(); var published = stat()
            if fstat(fd, &source) == 0, fstatat(rootFD, "manifest.json", &published, AT_SYMLINK_NOFOLLOW) == 0,
               source.st_dev == published.st_dev, source.st_ino == published.st_ino {
                _ = unlinkat(rootFD, "manifest.json", 0)
            }
            throw ActionEvidenceFailure(code: "action_evidence_write_failed")
        }
    }

    private func event(_ kind: TKEvidenceRunEventKind, receipt: TKActionReceipt? = nil) -> TKEvidenceRunEvent {
        TKEvidenceRunEvent(runID: context.actionID, timestamp: ISO8601DateFormatter().string(from: Date()), kind: kind,
            caseName: kind == .runStarted ? context.operation : nil,
            target: TKEvidenceRunTarget(platform: platform, runtimeTargetID: context.target),
            step: kind == .runStarted || kind == .runCompleted ? nil : 1,
            source: "action-coordinator", tool: context.operation,
            success: receipt.map { $0.outcome == .settled && $0.failureCode == nil }, error: receipt?.failureCode,
            artifactRefs: receipt?.evidenceRefs, status: receipt?.terminalStatus,
            verdict: kind == .runCompleted ? (receipt?.outcome == .settled && receipt?.failureCode == nil ? .success : .failure) : nil,
            stepCount: kind == .runCompleted ? 1 : nil, actionContext: receipt?.evidenceMetadata())
    }
    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    private func lines(_ values: [TKEvidenceRunEvent]) throws -> Data {
        try values.reduce(into: Data()) { $0.append(try encode($1)); $0.append(10) }
    }
    private func verifyIdentity() throws {
        let current = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard current >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
        defer { close(current) }
        var info = stat(); var runInfo = stat(); var heldRun = stat()
        guard fstat(current, &info) == 0, info.st_dev == device, info.st_ino == inode,
              fstatat(rootFD, "run", &runInfo, AT_SYMLINK_NOFOLLOW) == 0,
              fstat(runFD, &heldRun) == 0, runInfo.st_dev == heldRun.st_dev, runInfo.st_ino == heldRun.st_ino else {
            throw ActionEvidenceFailure(code: "action_evidence_write_failed")
        }
    }
    private func read(_ name: String, parent: Int32) throws -> Data {
        let fd = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
              info.st_size >= 0, info.st_size <= 1_048_576 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
        return try handle.read(upToCount: 1_048_577) ?? Data()
    }
    private func write(_ data: Data, name: String, parent: Int32) throws {
        let fd = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
        defer { close(fd) }
        try writeAll(data, fd: fd)
        guard fsync(parent) == 0 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
    }
    private func append(_ data: Data, name: String, parent: Int32) throws {
        let fd = openat(parent, name, O_WRONLY | O_APPEND | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1 else {
            throw ActionEvidenceFailure(code: "action_evidence_write_failed")
        }
        try writeAll(data, fd: fd)
    }
    private func writeAll(_ data: Data, fd: Int32) throws {
        let success = data.withUnsafeBytes { bytes -> Bool in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { return false }; offset += count
            }
            return true
        }
        guard success, fsync(fd) == 0 else { throw ActionEvidenceFailure(code: "action_evidence_write_failed") }
    }
}
