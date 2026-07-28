import CryptoKit
import Darwin
import Foundation
import TritonKitShared

/// Raw-byte hashes for the fixed evidence components that a receipt-bound
/// sample already produces. Paths deliberately stay out of this private model.
struct TKTestReliabilityIdentityChainArtifactSHA256: Codable, Equatable {
    let binding: String
    let resetReceipt: String
    let normalizedPlan: String
    let runtimeTarget: String
    let runMetadata: String
    let runEvents: String
}

/// In-memory raw components used to build or verify a v2 identity chain.
/// This type is intentionally not Codable: only their SHA-256 values persist.
struct TKTestReliabilityIdentityChainArtifactData: Equatable {
    var binding: Data
    var resetReceipt: Data
    var normalizedPlan: Data
    var runtimeTarget: Data
    var runMetadata: Data
    var runEvents: Data

    var sha256: TKTestReliabilityIdentityChainArtifactSHA256 {
        TKTestReliabilityIdentityChainArtifactSHA256(
            binding: reliabilityIdentityChainSHA256(binding),
            resetReceipt: reliabilityIdentityChainSHA256(resetReceipt),
            normalizedPlan: reliabilityIdentityChainSHA256(normalizedPlan),
            runtimeTarget: reliabilityIdentityChainSHA256(runtimeTarget),
            runMetadata: reliabilityIdentityChainSHA256(runMetadata),
            runEvents: reliabilityIdentityChainSHA256(runEvents)
        )
    }
}

/// The hashable, privacy-safe frozen identity for exactly one receipt slot.
/// It contains no local paths, target id, UDID, bundle, reset evidence id,
/// visible text, run id, or raw artifact content.
struct TKTestReliabilityIdentityChainBody: Codable, Equatable {
    let receiptSha256: String
    let legacyReceiptDigest: String
    let flowID: String
    let classification: TKTestReliabilityFrozenClassification
    let expectedOutcome: String
    let targetBindingDigest: String
    let planDigest: String
    let executionIdentityDigest: String
    let slot: Int
    let terminalStatus: TKTestRunStatus
    let outcomeMatched: Bool
    let artifactSha256: TKTestReliabilityIdentityChainArtifactSHA256
}

struct TKTestReliabilityIdentityChainV2: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let body: TKTestReliabilityIdentityChainBody
    let bodySha256: String

    init(body: TKTestReliabilityIdentityChainBody, bodySha256: String) {
        self.schemaVersion = 2
        self.kind = "triton.test.reliability-identity-chain"
        self.body = body
        self.bodySha256 = bodySha256
    }

    init(body: TKTestReliabilityIdentityChainBody) throws {
        self.init(
            body: body,
            bodySha256: reliabilityIdentityChainSHA256(try prettyEncodedData(body))
        )
    }
}

enum TKTestReliabilityIdentityChainState: String, Codable, Equatable {
    case notApplicable = "not_applicable"
    case verified
    case missing
    case invalid
}

struct TKTestReliabilityIdentityChainValidation: Equatable {
    let state: TKTestReliabilityIdentityChainState
    let issues: [String]
}

func summarizeTritonTestReliabilityIdentityChains(
    _ states: [TKTestReliabilityIdentityChainState],
    receiptAnchorVerified: Bool
) -> TKTestReliabilityIdentityChainSummary {
    let validSlotCount = states.filter { $0 == .verified }.count
    let missingSlotCount = states.filter { $0 == .missing }.count
    let invalidSlotCount = states.filter { $0 == .invalid }.count
    let state: TKTestReliabilityIdentityChainState
    if invalidSlotCount > 0 {
        state = .invalid
    } else if missingSlotCount > 0 {
        state = .missing
    } else if states.isEmpty {
        state = .notApplicable
    } else {
        state = .verified
    }
    return TKTestReliabilityIdentityChainSummary(
        state: state,
        expectedSlotCount: states.count,
        validSlotCount: validSlotCount,
        missingSlotCount: missingSlotCount,
        invalidSlotCount: invalidSlotCount,
        receiptAnchorVerified: receiptAnchorVerified
    )
}

enum TKTestReliabilityIdentityChainError: Error, Equatable {
    case requiredArtifactMissing
    case invalidTerminalStatus
    case writeFailed
}

func reliabilityIdentityChainSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func buildTritonTestReliabilityIdentityChainV2(
    descriptor: TKTestReliabilityIdentityChainBody,
    artifacts: TKTestReliabilityIdentityChainArtifactData
) throws -> TKTestReliabilityIdentityChainV2 {
    guard reliabilityIdentityChainHasTerminalStatus(descriptor.terminalStatus) else {
        throw TKTestReliabilityIdentityChainError.invalidTerminalStatus
    }
    let body = TKTestReliabilityIdentityChainBody(
        receiptSha256: descriptor.receiptSha256,
        legacyReceiptDigest: descriptor.legacyReceiptDigest,
        flowID: descriptor.flowID,
        classification: descriptor.classification,
        expectedOutcome: descriptor.expectedOutcome,
        targetBindingDigest: descriptor.targetBindingDigest,
        planDigest: descriptor.planDigest,
        executionIdentityDigest: descriptor.executionIdentityDigest,
        slot: descriptor.slot,
        terminalStatus: descriptor.terminalStatus,
        outcomeMatched: descriptor.outcomeMatched,
        artifactSha256: artifacts.sha256
    )
    return try TKTestReliabilityIdentityChainV2(body: body)
}

func validateTritonTestReliabilityIdentityChainV2(
    chainData: Data?,
    descriptor: TKTestReliabilityIdentityChainBody?,
    artifacts: TKTestReliabilityIdentityChainArtifactData,
    manifestDeclared: Bool
) -> TKTestReliabilityIdentityChainValidation {
    guard let chainData else {
        return TKTestReliabilityIdentityChainValidation(
            state: .missing,
            issues: ["identity_chain_missing"]
        )
    }
    guard let chain = try? JSONDecoder().decode(TKTestReliabilityIdentityChainV2.self, from: chainData),
          chain.schemaVersion == 2,
          chain.kind == "triton.test.reliability-identity-chain" else {
        return TKTestReliabilityIdentityChainValidation(
            state: .invalid,
            issues: ["identity_chain_invalid"]
        )
    }
    guard let descriptor else {
        return TKTestReliabilityIdentityChainValidation(
            state: .invalid,
            issues: ["identity_chain_terminal_unavailable"]
        )
    }
    guard reliabilityIdentityChainHasTerminalStatus(descriptor.terminalStatus) else {
        return TKTestReliabilityIdentityChainValidation(
            state: .invalid,
            issues: ["identity_chain_terminal_unavailable"]
        )
    }

    var issues: [String] = []
    if (try? prettyEncodedData(chain.body)).map(reliabilityIdentityChainSHA256) != chain.bodySha256 {
        issues.append("identity_chain_body_hash_mismatch")
    }
    if !reliabilityIdentityChainFrozenIdentityMatches(chain.body, descriptor) {
        issues.append("identity_chain_frozen_identity_mismatch")
    }
    if chain.body.artifactSha256 != artifacts.sha256 {
        issues.append("identity_chain_artifact_drift")
    }
    if !manifestDeclared {
        issues.append("identity_chain_manifest_invalid")
    }
    return TKTestReliabilityIdentityChainValidation(
        state: issues.isEmpty ? .verified : .invalid,
        issues: issues
    )
}

func makeTritonTestReliabilityIdentityChainDescriptor(
    receiptSha256: String,
    legacyReceiptDigest: String,
    targetBindingDigest: String,
    flow: TKTestReliabilityFrozenFlow,
    slot: TKTestReliabilityFrozenSlot,
    terminalStatus: TKTestRunStatus,
    outcomeMatched: Bool
) -> TKTestReliabilityIdentityChainBody {
    TKTestReliabilityIdentityChainBody(
        receiptSha256: receiptSha256,
        legacyReceiptDigest: legacyReceiptDigest,
        flowID: flow.flowID,
        classification: flow.classification,
        expectedOutcome: flow.expectedOutcome,
        targetBindingDigest: targetBindingDigest,
        planDigest: flow.planDigest,
        executionIdentityDigest: flow.executionIdentityDigest,
        slot: slot.slot,
        terminalStatus: terminalStatus,
        outcomeMatched: outcomeMatched,
        artifactSha256: TKTestReliabilityIdentityChainArtifactSHA256(
            binding: "",
            resetReceipt: "",
            normalizedPlan: "",
            runtimeTarget: "",
            runMetadata: "",
            runEvents: ""
        )
    )
}

func writeTritonTestReliabilityIdentityChainV2(
    evidenceURL: URL,
    descriptor: TKTestReliabilityIdentityChainBody
) throws -> Int {
    let artifacts = try reliabilityIdentityChainArtifacts(at: evidenceURL)
    let chain = try buildTritonTestReliabilityIdentityChainV2(
        descriptor: descriptor,
        artifacts: artifacts
    )
    let data = try prettyEncodedData(chain)
    let output = evidenceURL
        .appendingPathComponent("reliability", isDirectory: true)
        .appendingPathComponent("identity-chain-v2.json")
    try writeReliabilityIdentityChainExclusive(data, to: output)
    return data.count
}

func validateTritonTestReliabilityIdentityChainV2(
    evidenceURL: URL,
    descriptor: TKTestReliabilityIdentityChainBody?,
    manifest: TKEvidenceManifest?
) -> TKTestReliabilityIdentityChainValidation {
    let chainURL = evidenceURL
        .appendingPathComponent("reliability", isDirectory: true)
        .appendingPathComponent("identity-chain-v2.json")
    guard reliabilityIdentityChainRegularFile(at: chainURL),
          let chainData = try? Data(contentsOf: chainURL) else {
        return TKTestReliabilityIdentityChainValidation(
            state: .missing,
            issues: ["identity_chain_missing"]
        )
    }
    guard let artifacts = try? reliabilityIdentityChainArtifacts(at: evidenceURL) else {
        return TKTestReliabilityIdentityChainValidation(
            state: .invalid,
            issues: ["identity_chain_artifact_drift"]
        )
    }
    let manifestDeclared = manifest.map(reliabilityIdentityChainManifestDeclared) ?? false
    return validateTritonTestReliabilityIdentityChainV2(
        chainData: chainData,
        descriptor: descriptor,
        artifacts: artifacts,
        manifestDeclared: manifestDeclared
    )
}

private func reliabilityIdentityChainFrozenIdentityMatches(
    _ actual: TKTestReliabilityIdentityChainBody,
    _ expected: TKTestReliabilityIdentityChainBody
) -> Bool {
    actual.receiptSha256 == expected.receiptSha256 &&
        actual.legacyReceiptDigest == expected.legacyReceiptDigest &&
        actual.flowID == expected.flowID &&
        actual.classification == expected.classification &&
        actual.expectedOutcome == expected.expectedOutcome &&
        actual.targetBindingDigest == expected.targetBindingDigest &&
        actual.planDigest == expected.planDigest &&
        actual.executionIdentityDigest == expected.executionIdentityDigest &&
        actual.slot == expected.slot &&
        actual.terminalStatus == expected.terminalStatus &&
        actual.outcomeMatched == expected.outcomeMatched
}

private func reliabilityIdentityChainHasTerminalStatus(_ status: TKTestRunStatus) -> Bool {
    status == .passed || status == .failed || status == .blocked
}

private func reliabilityIdentityChainArtifacts(
    at evidenceURL: URL
) throws -> TKTestReliabilityIdentityChainArtifactData {
    TKTestReliabilityIdentityChainArtifactData(
        binding: try reliabilityIdentityChainRequiredData(
            at: evidenceURL.appendingPathComponent("reliability/binding.json")
        ),
        resetReceipt: try reliabilityIdentityChainRequiredData(
            at: evidenceURL.appendingPathComponent("reliability/reset-receipt.json")
        ),
        normalizedPlan: try reliabilityIdentityChainRequiredData(
            at: evidenceURL.appendingPathComponent("normalized-plan.json")
        ),
        runtimeTarget: try reliabilityIdentityChainRequiredData(
            at: evidenceURL.appendingPathComponent("runtime-target.json")
        ),
        runMetadata: try reliabilityIdentityChainRequiredData(
            at: evidenceURL.appendingPathComponent("run/run.json")
        ),
        runEvents: try reliabilityIdentityChainRequiredData(
            at: evidenceURL.appendingPathComponent("run/events.jsonl")
        )
    )
}

private func reliabilityIdentityChainRequiredData(at url: URL) throws -> Data {
    guard reliabilityIdentityChainRegularFile(at: url),
          let data = try? Data(contentsOf: url) else {
        throw TKTestReliabilityIdentityChainError.requiredArtifactMissing
    }
    return data
}

private func reliabilityIdentityChainRegularFile(at url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          !isDirectory.boolValue,
          (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) == nil else {
        return false
    }
    return true
}

private func reliabilityIdentityChainManifestDeclared(_ manifest: TKEvidenceManifest) -> Bool {
    manifest.artifacts.filter {
        $0.kind == "test.reliability.identity-chain-v2" &&
            $0.path == "reliability/identity-chain-v2.json" &&
            $0.scope == "private"
    }.count == 1
}

private func writeReliabilityIdentityChainExclusive(_ data: Data, to url: URL) throws {
    let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
        throw TKTestReliabilityIdentityChainError.writeFailed
    }
    defer { close(descriptor) }
    let writeResult = data.withUnsafeBytes { buffer in
        write(descriptor, buffer.baseAddress, buffer.count)
    }
    guard writeResult == data.count else {
        throw TKTestReliabilityIdentityChainError.writeFailed
    }
}
