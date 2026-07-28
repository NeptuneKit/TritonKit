import Darwin
import Foundation
import TritonKitShared

/// SP-140 deliberately keeps its collection state private. The receipt is the
/// only authority a later sample may use; source YAML paths are not retained.
enum TKTestReliabilityFrozenClassification: String, Codable, Equatable {
    case supported
    case negativeControl = "negative-control"
}

struct TKTestReliabilityFrozenSlot: Codable, Equatable {
    let slot: Int
    let evidenceRelativePath: String
}

struct TKTestReliabilityFrozenFlow: Codable, Equatable {
    let flowID: String
    let classification: TKTestReliabilityFrozenClassification
    let expectedOutcome: String
    let expectedFailureType: String?
    let normalizedPlan: TKTestNormalizedPlan
    let planDigest: String
    let executionIdentityDigest: String
    let initialStateID: String
    let resetRecipeID: String
    let slots: [TKTestReliabilityFrozenSlot]
}

struct TKTestReliabilityCollectionReceipt: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let collectionDigest: String
    let target: TKTestReliabilityCollectionTarget
    let flows: [TKTestReliabilityFrozenFlow]

    init(
        collectionDigest: String,
        target: TKTestReliabilityCollectionTarget,
        flows: [TKTestReliabilityFrozenFlow]
    ) {
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-collection-receipt"
        self.collectionDigest = collectionDigest
        self.target = target
        self.flows = flows
    }
}

/// The reset action itself remains operator-owned. This typed attestation
/// binds that action to one frozen sample without exposing reset commands.
struct TKTestReliabilityResetReceipt: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let collectionReceiptDigest: String
    let flowID: String
    let slot: Int
    let targetBindingDigest: String
    let initialStateID: String
    let resetRecipeID: String
    let resetEvidenceID: String
    let verified: Bool

    init(
        collectionReceiptDigest: String,
        flowID: String,
        slot: Int,
        targetBindingDigest: String,
        initialStateID: String,
        resetRecipeID: String,
        resetEvidenceID: String,
        verified: Bool
    ) {
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-reset-receipt"
        self.collectionReceiptDigest = collectionReceiptDigest
        self.flowID = flowID
        self.slot = slot
        self.targetBindingDigest = targetBindingDigest
        self.initialStateID = initialStateID
        self.resetRecipeID = resetRecipeID
        self.resetEvidenceID = resetEvidenceID
        self.verified = verified
    }
}

struct TKTestReliabilitySampleBinding: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let collectionReceiptDigest: String
    let flowID: String
    let classification: TKTestReliabilityFrozenClassification
    let expectedOutcome: String
    let expectedFailureType: String?
    let slot: Int
    let target: TKTestReliabilityCollectionTarget
    let planDigest: String
    let executionIdentityDigest: String
    let initialStateID: String
    let resetRecipeID: String
    let evidenceRelativePath: String

    init(
        collectionReceiptDigest: String,
        flow: TKTestReliabilityFrozenFlow,
        slot: TKTestReliabilityFrozenSlot,
        target: TKTestReliabilityCollectionTarget
    ) {
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-sample-binding"
        self.collectionReceiptDigest = collectionReceiptDigest
        self.flowID = flow.flowID
        self.classification = flow.classification
        self.expectedOutcome = flow.expectedOutcome
        self.expectedFailureType = flow.expectedFailureType
        self.slot = slot.slot
        self.target = target
        self.planDigest = flow.planDigest
        self.executionIdentityDigest = flow.executionIdentityDigest
        self.initialStateID = flow.initialStateID
        self.resetRecipeID = flow.resetRecipeID
        self.evidenceRelativePath = slot.evidenceRelativePath
    }
}

struct TKTestReliabilityReserveResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let writesEvidence: Bool
    let usesRuntime: Bool
    let receiptFile: String
    let receiptDigest: String
    let targetBindingDigest: String
    let supportedFlowCount: Int
    let negativeControlCount: Int
    let plannedSampleCount: Int

    init(receiptDigest: String, targetBindingDigest: String, flows: [TKTestReliabilityFrozenFlow]) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-reserve"
        self.writesEvidence = true
        self.usesRuntime = false
        self.receiptFile = "collection-receipt.json"
        self.receiptDigest = receiptDigest
        self.targetBindingDigest = targetBindingDigest
        self.supportedFlowCount = flows.filter { $0.classification == .supported }.count
        self.negativeControlCount = flows.filter { $0.classification == .negativeControl }.count
        self.plannedSampleCount = flows.reduce(0) { $0 + $1.slots.count }
    }
}

struct TKTestReliabilitySampleRequest: Equatable {
    let collectionReceipt: String
    let flow: String
    let slot: Int
    let resetReceipt: String
    let target: String
    let host: String
    let port: Int
    let confirm: Bool
}

/// The harness resolves the live target once, before claiming a slot. The
/// production resolver is deliberately injectable so contract tests prove no
/// primitive can run against a selector fallback or an unbound target.
protocol TKTestReliabilityRuntimeTargetResolver {
    func resolve(
        receiptTarget: TKTestReliabilityCollectionTarget,
        host: String,
        port: Int
    ) async throws -> TKTargetSummary
}

struct TKLiveTestReliabilityRuntimeTargetResolver: TKTestReliabilityRuntimeTargetResolver {
    func resolve(
        receiptTarget: TKTestReliabilityCollectionTarget,
        host: String,
        port: Int
    ) async throws -> TKTargetSummary {
        let client = TritonKitHTTPClient(host: host, port: port)
        let response: TKTargetsResponse = try await client.getJSON("/targets")
        return try resolveReliabilityHarnessExactRuntimeTarget(
            receiptTarget: receiptTarget,
            targets: response.targets
        )
    }
}

/// Pure exact-ID selection used by the live `/targets` preflight. It must not
/// reuse the generic target resolver because that intentionally supports
/// friendly Simulator UDID aliases for ordinary CLI commands.
func resolveReliabilityHarnessExactRuntimeTarget(
    receiptTarget: TKTestReliabilityCollectionTarget,
    targets: [TKTargetSummary]
) throws -> TKTargetSummary {
    let matches = targets.filter { $0.id == receiptTarget.id }
    guard matches.count == 1,
          let summary = matches.first,
          reliabilityHarnessRuntimeTargetMatchesReceipt(
              summary,
              receiptTarget: receiptTarget
          ) else {
        throw TKTestReliabilityHarnessError.invalidSampleRequest
    }
    return summary
}

struct TKTestReliabilitySampleResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let flowID: String
    let classification: TKTestReliabilityFrozenClassification
    let slot: Int
    let targetBindingDigest: String
    let planDigest: String
    let executionIdentityDigest: String
    let resetEvidenceDigest: String
    let evidenceRelativePath: String
    let runStatus: TKTestRunStatus
    let expectedOutcome: String
    let expectedFailureType: String?
    let actualFailureType: String?
    let outcomeMatched: Bool

    init(
        flow: TKTestReliabilityFrozenFlow,
        slot: TKTestReliabilityFrozenSlot,
        targetBindingDigest: String,
        resetEvidenceDigest: String,
        runStatus: TKTestRunStatus,
        actualFailureType: String?
    ) {
        let expectedPassed = flow.expectedOutcome == "passed"
        let outcomeMatched: Bool
        if expectedPassed {
            outcomeMatched = runStatus == .passed && actualFailureType == nil
        } else {
            outcomeMatched = runStatus == .failed
                && actualFailureType == flow.expectedFailureType
        }
        self.ok = outcomeMatched
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-sample"
        self.flowID = flow.flowID
        self.classification = flow.classification
        self.slot = slot.slot
        self.targetBindingDigest = targetBindingDigest
        self.planDigest = flow.planDigest
        self.executionIdentityDigest = flow.executionIdentityDigest
        self.resetEvidenceDigest = resetEvidenceDigest
        self.evidenceRelativePath = slot.evidenceRelativePath
        self.runStatus = runStatus
        self.expectedOutcome = flow.expectedOutcome
        self.expectedFailureType = flow.expectedFailureType
        self.actualFailureType = actualFailureType
        self.outcomeMatched = outcomeMatched
    }
}

enum TKTestReliabilityHarnessError: Error, Equatable {
    case invalidCollectionReceiptInput
    case reservationAlreadyExists
    case reservationWriteFailed
    case invalidReceipt
    case confirmationRequired
    case invalidSampleRequest
    case invalidResetReceipt
    case collectionBusy
    case slotAlreadyClaimed
    case runnerFailed
}

func testReliabilityHarnessErrorDetail(_ error: TKTestReliabilityHarnessError) -> TKCLIErrorDetail {
    switch error {
    case .invalidCollectionReceiptInput:
        return TKCLIErrorDetail(
            code: "invalid_reliability_collection",
            message: "Reliability reserve requires three distinct frozen imported iOS Simulator plans.",
            hint: "Fix the private collection, including unique normalized-plan and execution identities."
        )
    case .reservationAlreadyExists:
        return TKCLIErrorDetail(
            code: "reliability_reservation_exists",
            message: "The private reliability evidence root is already reserved.",
            hint: "Do not delete, overwrite, or reuse the existing receipt or sample slots."
        )
    case .reservationWriteFailed:
        return TKCLIErrorDetail(
            code: "reliability_reservation_write_failed",
            message: "The private reliability receipt could not be exclusively written.",
            hint: "Stop and inspect the newly reserved root without overwriting it."
        )
    case .invalidReceipt:
        return TKCLIErrorDetail(
            code: "invalid_reliability_receipt",
            message: "The reliability collection receipt is invalid, incomplete, or drifted.",
            hint: "Use the exact receipt created by reliability-reserve and do not edit it."
        )
    case .confirmationRequired:
        return TKCLIErrorDetail(
            code: "reliability_sample_confirmation_required",
            message: "reliability-sample requires --confirm before it can claim a private evidence slot or call the runner.",
            hint: "Review the receipt, reset attestation, target, host, and port; then rerun with --confirm."
        )
    case .invalidSampleRequest:
        return TKCLIErrorDetail(
            code: "invalid_reliability_sample_request",
            message: "The sample request must use the receipt's exact canonical target and loopback endpoint.",
            hint: "Use a receipt flow alias, declared slot, exact triton:ios-simulator target, 127.0.0.1, and port 19421."
        )
    case .invalidResetReceipt:
        return TKCLIErrorDetail(
            code: "invalid_reliability_reset_receipt",
            message: "The reset receipt does not attest to this exact frozen sample binding.",
            hint: "Create a verified reset receipt for the same receipt, flow, slot, target binding, initial state, and reset recipe."
        )
    case .collectionBusy:
        return TKCLIErrorDetail(
            code: "reliability_collection_busy",
            message: "Another reliability sample holds the collection-wide execution lease.",
            hint: "Do not remove the active lease or reuse a slot. Wait for the owner to finish; after an interrupted run, inspect the private receipt root before any operator-directed recovery."
        )
    case .slotAlreadyClaimed:
        return TKCLIErrorDetail(
            code: "reliability_slot_already_claimed",
            message: "The requested reliability evidence slot already exists or is not empty.",
            hint: "Do not clear or reuse it; select only an unclaimed receipt slot."
        )
    case .runnerFailed:
        return TKCLIErrorDetail(
            code: "test_reliability_sample_failed",
            message: "The frozen reliability sample could not complete its runner bridge.",
            hint: "Preserve the claimed private evidence slot and inspect its receipt sidecars before any further action."
        )
    }
}

func reserveTritonTestReliabilityCollection(
    collectionPath: String
) throws -> TKTestReliabilityReserveResponse {
    do {
        if reliabilityHarnessReservationExists(collectionPath: collectionPath) {
            throw TKTestReliabilityHarnessError.reservationAlreadyExists
        }
        do {
            _ = try buildTritonTestReliabilityCollectionPreflight(collectionPath: collectionPath)
        } catch {
            // Another reserve can win between the first root check and
            // preflight's fresh-root check. Preserve the collision meaning
            // rather than misreporting that valid collection as malformed.
            if reliabilityHarnessReservationExists(collectionPath: collectionPath) {
                throw TKTestReliabilityHarnessError.reservationAlreadyExists
            }
            throw error
        }
        let collectionData = try Data(contentsOf: URL(fileURLWithPath: collectionPath))
        let collection = try JSONDecoder().decode(TKTestReliabilityCollection.self, from: collectionData)
        guard collection.schemaVersion == 1,
              collection.kind == "triton.test.reliability-collection",
              reliabilityHarnessTargetIsCanonical(collection.target) else {
            throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
        }
        let root = try reliabilityHarnessEvidenceRoot(collection.evidenceRoot)
        let supportedFlows = try collection.flows.enumerated().map { index, flow in
            try freezeReliabilityFlow(
                flowID: String(format: "flow_%03d", index + 1),
                classification: .supported,
                expectedOutcome: "passed",
                expectedFailureType: nil,
                planPath: flow.plan,
                expectedPlanDigest: flow.expectedPlanDigest,
                initialStateID: flow.initialStateID,
                resetRecipeID: flow.resetRecipeID,
                slots: flow.slots,
                target: collection.target
            )
        }
        guard collection.negativeControls.count == 1,
              let negative = collection.negativeControls.first else {
            throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
        }
        let negativeFlow = try freezeReliabilityFlow(
            flowID: "negative_001",
            classification: .negativeControl,
            expectedOutcome: negative.expectedOutcome,
            expectedFailureType: negative.expectedFailureType,
            planPath: negative.plan,
            expectedPlanDigest: negative.expectedPlanDigest,
            initialStateID: negative.initialStateID,
            resetRecipeID: negative.resetRecipeID,
            slots: [negative.slot],
            target: collection.target
        )
        let flows = supportedFlows + [negativeFlow]
        try validateReliabilityFrozenFlowIdentities(flows)

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        } catch {
            throw TKTestReliabilityHarnessError.reservationAlreadyExists
        }

        let receipt = TKTestReliabilityCollectionReceipt(
            collectionDigest: fnv1a64Hex(collectionData),
            target: collection.target,
            flows: flows
        )
        let receiptData = try prettyEncodedData(receipt)
        do {
            try writeReliabilityHarnessExclusive(
                receiptData,
                to: root.appendingPathComponent("collection-receipt.json")
            )
        } catch {
            throw TKTestReliabilityHarnessError.reservationWriteFailed
        }
        return TKTestReliabilityReserveResponse(
            receiptDigest: fnv1a64Hex(receiptData),
            targetBindingDigest: receipt.target.bindingDigest,
            flows: flows
        )
    } catch let error as TKTestReliabilityHarnessError {
        if error == .invalidReceipt {
            throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
        }
        throw error
    } catch {
        throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
    }
}

private func reliabilityHarnessReservationExists(collectionPath: String) -> Bool {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: collectionPath)),
          let collection = try? JSONDecoder().decode(TKTestReliabilityCollection.self, from: data),
          let root = try? reliabilityHarnessEvidenceRoot(collection.evidenceRoot) else {
        return false
    }
    return FileManager.default.fileExists(atPath: root.path)
}

func runTritonTestReliabilitySample(
    request: TKTestReliabilitySampleRequest,
    executor: TKTestRunPrimitiveExecutor,
    targetResolver: TKTestReliabilityRuntimeTargetResolver
) async throws -> TKTestReliabilitySampleResponse {
    guard request.confirm else {
        throw TKTestReliabilityHarnessError.confirmationRequired
    }
    let loaded = try loadReliabilityCollectionReceipt(at: request.collectionReceipt)
    guard request.host == "127.0.0.1",
          request.port == 19421,
          request.target == loaded.receipt.target.id,
          let flow = loaded.receipt.flows.first(where: { $0.flowID == request.flow }),
          let slot = flow.slots.first(where: { $0.slot == request.slot }) else {
        throw TKTestReliabilityHarnessError.invalidSampleRequest
    }
    let reset = try loadAndValidateReliabilityResetReceipt(
        at: request.resetReceipt,
        receiptDigest: loaded.digest,
        receipt: loaded.receipt,
        flow: flow,
        slot: slot
    )
    let collectionLease = try claimReliabilityHarnessCollectionLease(root: loaded.root)
    defer { collectionLease.release() }
    let resolvedTarget: TKTargetSummary
    do {
        resolvedTarget = try await targetResolver.resolve(
            receiptTarget: loaded.receipt.target,
            host: request.host,
            port: request.port
        )
    } catch {
        throw TKTestReliabilityHarnessError.invalidSampleRequest
    }
    guard reliabilityHarnessRuntimeTargetMatchesReceipt(
        resolvedTarget,
        receiptTarget: loaded.receipt.target
    ) else {
        throw TKTestReliabilityHarnessError.invalidSampleRequest
    }
    if let liveExecutor = executor as? TKLiveTestRunPrimitiveExecutor {
        liveExecutor.pinReliabilityRuntimeTarget(
            resolvedTarget,
            host: request.host,
            port: request.port
        )
    }
    let evidenceURL = try claimReliabilityHarnessEvidenceSlot(
        root: loaded.root,
        slot: slot
    )

    let binding = TKTestReliabilitySampleBinding(
        collectionReceiptDigest: loaded.digest,
        flow: flow,
        slot: slot,
        target: loaded.receipt.target
    )
    let bindingData = try prettyEncodedData(binding)
    let resetData = reset.data
    let reliabilityDirectory = evidenceURL.appendingPathComponent("reliability", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: reliabilityDirectory, withIntermediateDirectories: false)
        try writeReliabilityHarnessExclusive(bindingData, to: reliabilityDirectory.appendingPathComponent("binding.json"))
        try writeReliabilityHarnessExclusive(resetData, to: reliabilityDirectory.appendingPathComponent("reset-receipt.json"))
    } catch {
        throw TKTestReliabilityHarnessError.slotAlreadyClaimed
    }

    do {
        let execution = try await runTritonFrozenTest(
            normalizedPlan: flow.normalizedPlan,
            evidenceDirectory: evidenceURL.path,
            target: request.target,
            host: request.host,
            port: request.port,
            executor: executor
        )
        try appendReliabilityHarnessArtifacts(
            evidenceURL: evidenceURL,
            bindingBytes: bindingData.count,
            resetBytes: resetData.count,
            target: loaded.receipt.target.id
        )
        return TKTestReliabilitySampleResponse(
            flow: flow,
            slot: slot,
            targetBindingDigest: loaded.receipt.target.bindingDigest,
            resetEvidenceDigest: fnv1a64Hex(resetData),
            runStatus: execution.summary.status ?? (execution.ok ? .passed : .failed),
            actualFailureType: execution.failure?.type
        )
    } catch {
        throw TKTestReliabilityHarnessError.runnerFailed
    }
}

func buildTritonTestReliabilityReceiptReport(
    collectionReceiptPath: String,
    thresholds: TKTestReliabilityThresholds = TKTestReliabilityThresholds()
) throws -> TKTestReliabilityReport {
    let loaded = try loadReliabilityCollectionReceipt(at: collectionReceiptPath)
    var samples: [TKTestReliabilitySample] = []
    var extraIssues: [String: Int] = [:]

    for flow in loaded.receipt.flows {
        for slot in flow.slots {
            let evidenceURL = try reliabilityHarnessContainedEvidenceURL(
                root: loaded.root,
                relativePath: slot.evidenceRelativePath
            )
            let validation = validateReliabilityReceiptEvidence(
                evidenceURL: evidenceURL,
                receiptDigest: loaded.digest,
                receipt: loaded.receipt,
                flow: flow,
                slot: slot
            )
            for issue in validation.issues {
                extraIssues[issue, default: 0] += 1
            }
            samples.append(TKTestReliabilitySample(
                flowID: flow.flowID,
                classification: flow.classification == .supported ? .supported : .negativeControl,
                evidence: evidenceURL.path,
                initialStateID: flow.initialStateID,
                resetEvidenceID: validation.resetEvidenceID ?? "missing-reset-\(flow.flowID)-\(slot.slot)",
                targetToken: loaded.receipt.target.id
            ))
        }
    }

    let base = try buildTritonTestReliabilityReceiptReport(samples: samples, thresholds: thresholds)
    var issueCounts = base.issueCounts
    for (issue, count) in extraIssues {
        issueCounts[issue, default: 0] += count
    }
    var blockers = base.gate.blockerCodes
    if !extraIssues.isEmpty {
        blockers.append("receipt_binding_invalid")
    }
    let gate = TKTestReliabilityGate(
        status: blockers.isEmpty ? .passed : .blocked,
        blockerCodes: Array(Set(blockers)).sorted()
    )
    return TKTestReliabilityReport(
        gateAuthority: base.gateAuthority,
        thresholds: base.thresholds,
        evidenceCompleteness: base.evidenceCompleteness,
        failureExplainability: base.failureExplainability,
        outcomeRepeatability: base.outcomeRepeatability,
        flows: base.flows,
        issueCounts: issueCounts,
        gate: gate
    )
}

private struct ReliabilityHarnessLoadedReceipt {
    let receipt: TKTestReliabilityCollectionReceipt
    let data: Data
    let digest: String
    let root: URL
}

private struct ReliabilityHarnessResetReceipt {
    let receipt: TKTestReliabilityResetReceipt
    let data: Data
}

private struct ReliabilityHarnessEvidenceValidation {
    let resetEvidenceID: String?
    let issues: [String]
}

private struct TKTestReliabilityExecutionIdentity: Codable, Equatable {
    let bundleID: String
    let platform: String
    let strict: Bool
    let timeoutMs: Int
    let retryCount: Int
    let retryIntervalMs: Int
    let steps: [TKTestReliabilityExecutionStepIdentity]
}

private struct TKTestReliabilityExecutionStepIdentity: Codable, Equatable {
    let type: String
    let optional: Bool
    let timeoutMs: Int?
    let point: TKTestPlanPoint?
    let endPoint: TKTestPlanPoint?
    let selector: TKTestPlanSelector?
    let text: String?
    let button: String?
    let direction: String?
    let maxScrolls: Int?
    let target: String?
    let grounding: String?
    let provider: String?
    let model: String?
    let modelPath: String?
    let maxTokens: Int?
    let temperature: Double?
    let seed: Int?
    let promptTemplate: String?
    let allowModelDownload: Bool?
    let prompt: String?
    let baseline: String?
    let threshold: Double?
    let cropOn: String?

    init(_ step: TKTestPlanStep) {
        self.type = step.type
        self.optional = step.optional
        self.timeoutMs = step.timeoutMs
        self.point = step.point
        self.endPoint = step.endPoint
        self.selector = step.selector
        self.text = step.text
        self.button = step.button
        self.direction = step.direction
        self.maxScrolls = step.maxScrolls
        self.target = step.target
        self.grounding = step.grounding
        self.provider = step.provider
        self.model = step.model
        self.modelPath = step.modelPath
        self.maxTokens = step.maxTokens
        self.temperature = step.temperature
        self.seed = step.seed
        self.promptTemplate = step.promptTemplate
        self.allowModelDownload = step.allowModelDownload
        self.prompt = step.prompt
        self.baseline = step.baseline
        self.threshold = step.threshold
        self.cropOn = step.cropOn
    }
}

private func freezeReliabilityFlow(
    flowID: String,
    classification: TKTestReliabilityFrozenClassification,
    expectedOutcome: String,
    expectedFailureType: String?,
    planPath: String,
    expectedPlanDigest: String,
    initialStateID: String,
    resetRecipeID: String,
    slots: [Int],
    target: TKTestReliabilityCollectionTarget
) throws -> TKTestReliabilityFrozenFlow {
    guard reliabilityHarnessIdentifier(flowID),
          reliabilityHarnessIdentifier(initialStateID),
          reliabilityHarnessIdentifier(resetRecipeID),
          reliabilityHarnessDigest(expectedPlanDigest),
          ((classification == .supported
                && expectedOutcome == "passed"
                && expectedFailureType == nil)
            || (classification == .negativeControl
                && expectedOutcome == "nonpassed"
                && expectedFailureType != nil)),
          !slots.isEmpty else {
        throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
    }
    let yaml = try String(contentsOf: URL(fileURLWithPath: planPath), encoding: .utf8)
    let normalizedPlan = try validateTritonTestContract(yaml: yaml, inputPath: planPath)
    guard reliabilityHarnessTargetMatchesPlan(target, plan: normalizedPlan) else {
        throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
    }
    if classification == .negativeControl {
        guard let expectedFailureType,
              isTritonTestReliabilityDeterministicNegativeControl(
                  plan: normalizedPlan,
                  expectedFailureType: expectedFailureType
              ) else {
            throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
        }
    }
    let normalizedData = try prettyEncodedData(normalizedPlan)
    let planDigest = fnv1a64Hex(normalizedData)
    guard planDigest == expectedPlanDigest else {
        throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
    }
    let identity = TKTestReliabilityExecutionIdentity(
        bundleID: normalizedPlan.app.bundleId,
        platform: normalizedPlan.device.platform,
        strict: normalizedPlan.settings.strict,
        timeoutMs: normalizedPlan.settings.timeoutMs,
        retryCount: normalizedPlan.settings.retry.count,
        retryIntervalMs: normalizedPlan.settings.retry.intervalMs,
        steps: normalizedPlan.steps.map(TKTestReliabilityExecutionStepIdentity.init)
    )
    let executionIdentityDigest = fnv1a64Hex(try prettyEncodedData(identity))
    let frozenSlots = try slots.map { slot -> TKTestReliabilityFrozenSlot in
        guard slot > 0 else { throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput }
        let relative = "\(flowID)/sample-\(String(format: "%03d", slot)).tritonevidence"
        return TKTestReliabilityFrozenSlot(slot: slot, evidenceRelativePath: relative)
    }
    guard Set(frozenSlots.map(\.slot)).count == frozenSlots.count else {
        throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
    }
    return TKTestReliabilityFrozenFlow(
        flowID: flowID,
        classification: classification,
        expectedOutcome: expectedOutcome,
        expectedFailureType: expectedFailureType,
        normalizedPlan: normalizedPlan,
        planDigest: planDigest,
        executionIdentityDigest: executionIdentityDigest,
        initialStateID: initialStateID,
        resetRecipeID: resetRecipeID,
        slots: frozenSlots
    )
}

private func validateReliabilityFrozenFlowIdentities(
    _ flows: [TKTestReliabilityFrozenFlow]
) throws {
    guard flows.count == 4,
          flows.map(\.flowID) == ["flow_001", "flow_002", "flow_003", "negative_001"],
          flows.filter({ $0.classification == .supported }).count == 3,
          flows.filter({ $0.classification == .negativeControl }).count == 1,
          Set(flows.map(\.flowID)).count == flows.count,
          Set(flows.map(\.planDigest)).count == flows.count,
          Set(flows.map(\.executionIdentityDigest)).count == flows.count,
          flows.filter({ $0.classification == .supported }).allSatisfy({ $0.expectedOutcome == "passed" }),
          flows.filter({ $0.classification == .negativeControl }).allSatisfy({ $0.expectedOutcome == "nonpassed" }),
          flows.filter({ $0.classification == .supported }).allSatisfy({ $0.expectedFailureType == nil }),
          flows.filter({ $0.classification == .negativeControl }).allSatisfy({ flow in
              guard let expectedFailureType = flow.expectedFailureType else { return false }
              return isTritonTestReliabilityDeterministicNegativeControl(
                  plan: flow.normalizedPlan,
                  expectedFailureType: expectedFailureType
              )
          }),
          flows.filter({ $0.classification == .supported }).allSatisfy({ $0.slots.map(\.slot) == Array(1...20) }),
          flows.filter({ $0.classification == .negativeControl }).allSatisfy({ $0.slots.map(\.slot) == [1] }) else {
        throw TKTestReliabilityHarnessError.invalidCollectionReceiptInput
    }
}

private func loadReliabilityCollectionReceipt(
    at path: String
) throws -> ReliabilityHarnessLoadedReceipt {
    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let receipt = try? JSONDecoder().decode(TKTestReliabilityCollectionReceipt.self, from: data),
          receipt.schemaVersion == 1,
          receipt.kind == "triton.test.reliability-collection-receipt",
          reliabilityHarnessDigest(receipt.collectionDigest),
          reliabilityHarnessTargetIsCanonical(receipt.target) else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    let receiptURL = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    let root = receiptURL.deletingLastPathComponent().standardizedFileURL
    let expectedReceiptURL = root.appendingPathComponent("collection-receipt.json").standardizedFileURL
    guard receiptURL == expectedReceiptURL,
          FileManager.default.fileExists(atPath: root.path) else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    do {
        try validateReliabilityFrozenFlowIdentities(receipt.flows)
        for flow in receipt.flows {
            guard reliabilityHarnessDigest(flow.planDigest),
                  reliabilityHarnessDigest(flow.executionIdentityDigest),
                  reliabilityHarnessTargetMatchesPlan(receipt.target, plan: flow.normalizedPlan),
                  fnv1a64Hex(try prettyEncodedData(flow.normalizedPlan)) == flow.planDigest,
                  reliabilityHarnessExecutionIdentityDigest(for: flow.normalizedPlan) == flow.executionIdentityDigest else {
                throw TKTestReliabilityHarnessError.invalidReceipt
            }
            for slot in flow.slots {
                let expected = "\(flow.flowID)/sample-\(String(format: "%03d", slot.slot)).tritonevidence"
                guard slot.evidenceRelativePath == expected else {
                    throw TKTestReliabilityHarnessError.invalidReceipt
                }
                _ = try reliabilityHarnessContainedEvidenceURL(root: root, relativePath: slot.evidenceRelativePath)
            }
        }
    } catch let error as TKTestReliabilityHarnessError {
        throw error == .invalidCollectionReceiptInput ? .invalidReceipt : error
    } catch {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    return ReliabilityHarnessLoadedReceipt(
        receipt: receipt,
        data: data,
        digest: fnv1a64Hex(data),
        root: root
    )
}

private func loadAndValidateReliabilityResetReceipt(
    at path: String,
    receiptDigest: String,
    receipt: TKTestReliabilityCollectionReceipt,
    flow: TKTestReliabilityFrozenFlow,
    slot: TKTestReliabilityFrozenSlot
) throws -> ReliabilityHarnessResetReceipt {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let reset = try? JSONDecoder().decode(TKTestReliabilityResetReceipt.self, from: data),
          reset.schemaVersion == 1,
          reset.kind == "triton.test.reliability-reset-receipt",
          reset.collectionReceiptDigest == receiptDigest,
          reset.flowID == flow.flowID,
          reset.slot == slot.slot,
          reset.targetBindingDigest == receipt.target.bindingDigest,
          reset.initialStateID == flow.initialStateID,
          reset.resetRecipeID == flow.resetRecipeID,
          reliabilityHarnessIdentifier(reset.resetEvidenceID),
          reset.verified else {
        throw TKTestReliabilityHarnessError.invalidResetReceipt
    }
    return ReliabilityHarnessResetReceipt(receipt: reset, data: data)
}

private func validateReliabilityReceiptEvidence(
    evidenceURL: URL,
    receiptDigest: String,
    receipt: TKTestReliabilityCollectionReceipt,
    flow: TKTestReliabilityFrozenFlow,
    slot: TKTestReliabilityFrozenSlot
) -> ReliabilityHarnessEvidenceValidation {
    var issues: [String] = []
    let reliabilityURL = evidenceURL.appendingPathComponent("reliability", isDirectory: true)
    let bindingURL = reliabilityURL.appendingPathComponent("binding.json")
    let resetURL = reliabilityURL.appendingPathComponent("reset-receipt.json")
    let bindingData = try? Data(contentsOf: bindingURL)
    let binding = bindingData.flatMap { try? JSONDecoder().decode(TKTestReliabilitySampleBinding.self, from: $0) }
    let resetData = try? Data(contentsOf: resetURL)
    let reset = resetData.flatMap { try? JSONDecoder().decode(TKTestReliabilityResetReceipt.self, from: $0) }
    let expectedBinding = TKTestReliabilitySampleBinding(
        collectionReceiptDigest: receiptDigest,
        flow: flow,
        slot: slot,
        target: receipt.target
    )
    if binding != expectedBinding {
        issues.append("receipt_binding_sidecar_invalid")
    }
    if reset?.schemaVersion != 1 ||
        reset?.kind != "triton.test.reliability-reset-receipt" ||
        reset == nil || !(reset?.verified ?? false) ||
        reset?.collectionReceiptDigest != receiptDigest ||
        reset?.flowID != flow.flowID ||
        reset?.slot != slot.slot ||
        reset?.targetBindingDigest != receipt.target.bindingDigest ||
        reset?.initialStateID != flow.initialStateID ||
        reset?.resetRecipeID != flow.resetRecipeID ||
        !(reset.map { reliabilityHarnessIdentifier($0.resetEvidenceID) } ?? false) {
        issues.append("receipt_reset_sidecar_invalid")
    }
    let planURL = evidenceURL.appendingPathComponent("normalized-plan.json")
    if let data = try? Data(contentsOf: planURL),
       let plan = try? JSONDecoder().decode(TKTestNormalizedPlan.self, from: data),
       fnv1a64Hex(data) == flow.planDigest,
       reliabilityHarnessExecutionIdentityDigest(for: plan) == flow.executionIdentityDigest {
        // Frozen receipt plan matches the evidence plan.
    } else {
        issues.append("receipt_plan_drift")
    }
    let runtimeTargetURL = evidenceURL.appendingPathComponent("runtime-target.json")
    if let data = try? Data(contentsOf: runtimeTargetURL),
       let target = try? JSONDecoder().decode(TKTargetSummary.self, from: data),
       target.id == receipt.target.id,
       target.connected,
       target.platform.lowercased() == "ios",
       target.simulatorUDID == receipt.target.simulatorUDID,
       target.bundleIdentifier == receipt.target.bundleID {
        // The live runner recorded exactly the receipt-bound runtime target.
    } else {
        issues.append("receipt_runtime_target_drift")
    }
    if let manifest = try? readEvidenceManifest(from: evidenceURL.path) {
        let bindings = manifest.artifacts.filter { $0.kind == "test.reliability.binding" }
        let resetReceipts = manifest.artifacts.filter { $0.kind == "test.reliability.reset-receipt" }
        if bindings.isEmpty || resetReceipts.isEmpty {
            issues.append("receipt_manifest_sidecars_missing")
        }
        if bindings.count != 1 ||
            bindings.first?.path != "reliability/binding.json" ||
            resetReceipts.count != 1 ||
            resetReceipts.first?.path != "reliability/reset-receipt.json" {
            issues.append("receipt_manifest_sidecars_invalid")
        }
        if flow.classification == .supported,
           manifest.run?.summary?.verdict != .success {
            issues.append("supported_flow_nonpassed")
        }
        if flow.classification == .negativeControl,
           manifest.run?.summary?.verdict == .success {
            issues.append("negative_control_passed")
        }
    } else {
        issues.append("receipt_manifest_missing")
    }
    if flow.classification == .negativeControl {
        let terminalFailure = reliabilityHarnessTerminalFailure(in: evidenceURL)
        if terminalFailure.status != .failed ||
            terminalFailure.failure?.type != flow.expectedFailureType {
            issues.append("negative_control_failure_type_mismatch")
        }
    }
    return ReliabilityHarnessEvidenceValidation(
        resetEvidenceID: reset?.resetEvidenceID,
        issues: issues
    )
}

private func reliabilityHarnessTerminalFailure(
    in evidenceURL: URL
) -> (status: TKTestRunStatus?, failure: TKTestRunFailure?) {
    guard let manifest = try? readEvidenceManifest(from: evidenceURL.path),
          let eventsPath = manifest.run?.eventsPath,
          let eventsURL = try? reliabilityHarnessContainedEvidenceURL(
              root: evidenceURL,
              relativePath: eventsPath
          ),
          reliabilityHarnessRegularFile(at: eventsURL),
          let data = try? Data(contentsOf: eventsURL),
          let parsed = try? TKTestRunEventLogParser().parse(data) else {
        return (nil, nil)
    }
    let status = parsed.summary.status
    return (
        status,
        reliabilityTerminalFailure(from: parsed.events, status: status)?.failure
    )
}

private func reliabilityHarnessRegularFile(at url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          !isDirectory.boolValue,
          (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) == nil else {
        return false
    }
    return true
}

private func appendReliabilityHarnessArtifacts(
    evidenceURL: URL,
    bindingBytes: Int,
    resetBytes: Int,
    target: String
) throws {
    let manifestURL = evidenceURL.appendingPathComponent("manifest.json")
    let manifestData = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(TKEvidenceManifest.self, from: manifestData)
    let additions = [
        TKEvidenceArtifact(
            kind: "test.reliability.binding",
            path: "reliability/binding.json",
            contentType: "application/json",
            bytes: bindingBytes,
            scope: "private",
            source: "reliability-harness",
            target: target
        ),
        TKEvidenceArtifact(
            kind: "test.reliability.reset-receipt",
            path: "reliability/reset-receipt.json",
            contentType: "application/json",
            bytes: resetBytes,
            scope: "private",
            source: "reliability-harness",
            target: target
        ),
    ]
    let updated = TKEvidenceManifest(
        ok: manifest.ok,
        partial: manifest.partial,
        error: manifest.error,
        formatVersion: manifest.formatVersion,
        name: manifest.name,
        note: manifest.note,
        createdAt: manifest.createdAt,
        output: manifest.output,
        artifacts: manifest.artifacts + additions,
        primaryArtifact: manifest.primaryArtifact,
        primaryArtifacts: manifest.primaryArtifacts,
        skipped: manifest.skipped,
        target: manifest.target,
        cli: manifest.cli,
        run: manifest.run,
        screenWorkspace: manifest.screenWorkspace
    )
    try prettyEncodedData(updated).write(to: manifestURL, options: .atomic)
}

private func reliabilityHarnessEvidenceRoot(_ path: String) throws -> URL {
    guard path.hasPrefix("/") else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    let root = URL(fileURLWithPath: path, isDirectory: true)
        .resolvingSymlinksInPath()
        .standardizedFileURL
    let parent = root.deletingLastPathComponent()
    var isDirectory: ObjCBool = false
    guard !root.path.isEmpty,
          FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    return root
}

private func reliabilityHarnessContainedEvidenceURL(root: URL, relativePath: String) throws -> URL {
    guard !relativePath.hasPrefix("/"),
          !relativePath.contains("..") else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    let candidate = root.appendingPathComponent(relativePath, isDirectory: true).standardizedFileURL
    guard candidate.path.hasPrefix(root.path + "/") else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    return candidate
}

/// A receipt root permits one active sample at a time, regardless of flow or
/// slot. The lease is deliberately fail-closed: normal returns remove only the
/// empty directory this invocation created, while a crash leaves it behind for
/// explicit operator inspection rather than silently allowing concurrent
/// collection against the same Simulator.
private struct TKTestReliabilityCollectionLease {
    let url: URL

    func release() {
        _ = url.path.withCString { path in
            rmdir(path)
        }
    }
}

private func claimReliabilityHarnessCollectionLease(
    root: URL
) throws -> TKTestReliabilityCollectionLease {
    let leaseURL = root
        .appendingPathComponent(".reliability-active-sample", isDirectory: true)
        .standardizedFileURL
    guard leaseURL.path.hasPrefix(root.path + "/") else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }
    let created = leaseURL.path.withCString { path in
        mkdir(path, S_IRWXU)
    }
    guard created == 0 else {
        throw TKTestReliabilityHarnessError.collectionBusy
    }
    return TKTestReliabilityCollectionLease(url: leaseURL)
}

/// Only the final slot directory is the ownership lease. `mkdir` makes that
/// claim atomic and, unlike the general test-run path, never accepts an
/// existing empty directory that could contain stale run or manifest data.
private func claimReliabilityHarnessEvidenceSlot(
    root: URL,
    slot: TKTestReliabilityFrozenSlot
) throws -> URL {
    let evidenceURL = try reliabilityHarnessContainedEvidenceURL(
        root: root,
        relativePath: slot.evidenceRelativePath
    )
    let flowURL = evidenceURL.deletingLastPathComponent().standardizedFileURL
    guard flowURL.path.hasPrefix(root.path + "/") else {
        throw TKTestReliabilityHarnessError.invalidReceipt
    }

    let fileManager = FileManager.default
    var isDirectory = ObjCBool(false)
    if fileManager.fileExists(atPath: flowURL.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue,
              (try? fileManager.destinationOfSymbolicLink(atPath: flowURL.path)) == nil else {
            throw TKTestReliabilityHarnessError.slotAlreadyClaimed
        }
    } else {
        do {
            try fileManager.createDirectory(at: flowURL, withIntermediateDirectories: false)
        } catch {
            var racedDirectory = ObjCBool(false)
            guard fileManager.fileExists(atPath: flowURL.path, isDirectory: &racedDirectory),
                  racedDirectory.boolValue,
                  (try? fileManager.destinationOfSymbolicLink(atPath: flowURL.path)) == nil else {
                throw TKTestReliabilityHarnessError.slotAlreadyClaimed
            }
        }
    }

    let created = evidenceURL.path.withCString { path in
        mkdir(path, S_IRWXU)
    }
    guard created == 0 else {
        throw TKTestReliabilityHarnessError.slotAlreadyClaimed
    }
    return evidenceURL
}

private func reliabilityHarnessTargetIsCanonical(_ target: TKTestReliabilityCollectionTarget) -> Bool {
    guard let uuid = UUID(uuidString: target.simulatorUDID),
          uuid.uuidString == target.simulatorUDID,
          !target.bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return false
    }
    let canonicalID = TKIOSSimulatorRuntimeTargetID(
        simulatorUDID: uuid.uuidString,
        bundleIdentifier: target.bundleID
    )
    return target.id == canonicalID
        && target.bindingDigest == fnv1a64Hex(Data(canonicalID.utf8))
        && reliabilityHarnessDigest(target.bindingDigest)
}

private func reliabilityHarnessTargetMatchesPlan(
    _ target: TKTestReliabilityCollectionTarget,
    plan: TKTestNormalizedPlan
) -> Bool {
    target.bundleID == plan.app.bundleId
        && plan.device.platform == "ios-simulator"
        && plan.settings.strict
        && plan.settings.retry.count == 0
        && plan.steps.first?.type == "launch"
        && plan.provenance?.sourceKind == "triton.testrec.compiled-contract"
        && ["ios", "ios-simulator"].contains(plan.provenance?.sourcePlatform ?? "")
}

private func reliabilityHarnessRuntimeTargetMatchesReceipt(
    _ summary: TKTargetSummary,
    receiptTarget: TKTestReliabilityCollectionTarget
) -> Bool {
    summary.id == receiptTarget.id
        && summary.connected
        && summary.platform.lowercased() == "ios"
        && summary.simulatorUDID == receiptTarget.simulatorUDID
        && summary.bundleIdentifier == receiptTarget.bundleID
}

private func reliabilityHarnessExecutionIdentityDigest(for plan: TKTestNormalizedPlan) -> String? {
    guard reliabilityHarnessTargetMatchesPlan(
        TKTestReliabilityCollectionTarget(
            id: TKIOSSimulatorRuntimeTargetID(simulatorUDID: "00000000-0000-0000-0000-000000000000", bundleIdentifier: plan.app.bundleId),
            simulatorUDID: "00000000-0000-0000-0000-000000000000",
            bundleID: plan.app.bundleId,
            bindingDigest: "0000000000000000"
        ),
        plan: plan
    ) else {
        return nil
    }
    let identity = TKTestReliabilityExecutionIdentity(
        bundleID: plan.app.bundleId,
        platform: plan.device.platform,
        strict: plan.settings.strict,
        timeoutMs: plan.settings.timeoutMs,
        retryCount: plan.settings.retry.count,
        retryIntervalMs: plan.settings.retry.intervalMs,
        steps: plan.steps.map(TKTestReliabilityExecutionStepIdentity.init)
    )
    guard let data = try? prettyEncodedData(identity) else {
        return nil
    }
    return fnv1a64Hex(data)
}

private func reliabilityHarnessIdentifier(_ value: String) -> Bool {
    value.range(of: #"^[a-z0-9][a-z0-9_-]{0,127}$"#, options: .regularExpression) != nil
}

private func reliabilityHarnessDigest(_ value: String) -> Bool {
    value.range(of: #"^[0-9a-f]{16}$"#, options: .regularExpression) != nil
}

private func writeReliabilityHarnessExclusive(_ data: Data, to url: URL) throws {
    let flags = O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW
    let descriptor = open(url.path, flags, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
        throw TKTestReliabilityHarnessError.reservationWriteFailed
    }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer { try? handle.close() }
    try handle.write(contentsOf: data)
}
