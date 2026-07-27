import Foundation
import TritonKitShared

/// A private operator-owned declaration used only to freeze the inputs for a
/// future, separately authorized reliability collection. It is deliberately
/// not a sample manifest and never contains a real run, receipt, or verdict.
struct TKTestReliabilityCollection: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let target: TKTestReliabilityCollectionTarget
    let evidenceRoot: String
    let flows: [TKTestReliabilityCollectionFlow]
    let negativeControls: [TKTestReliabilityCollectionNegativeControl]
}

/// Private canonical identity for the one dedicated Simulator/App pairing.
/// The public preflight response exposes only `bindingDigest`.
struct TKTestReliabilityCollectionTarget: Codable, Equatable {
    let id: String
    let simulatorUDID: String
    let bundleID: String
    let bindingDigest: String
}

struct TKTestReliabilityCollectionFlow: Codable, Equatable {
    let flowID: String
    let plan: String
    let expectedPlanDigest: String
    let initialStateID: String
    let resetRecipeID: String
    let slots: [Int]
}

struct TKTestReliabilityCollectionNegativeControl: Codable, Equatable {
    let flowID: String
    let plan: String
    let expectedPlanDigest: String
    let initialStateID: String
    let resetRecipeID: String
    let slot: Int
    let expectedOutcome: String
}

enum TKTestReliabilityCollectionPreflightStatus: String, Codable, Equatable {
    case readyToCollect = "ready_to_collect"
}

struct TKTestReliabilityCollectionPreflightFlow: Codable, Equatable {
    let flowID: String
    let plannedRunCount: Int
    let planDigest: String
}

/// A safe collection declaration result. `ready_to_collect` is intentionally
/// not a reliability verdict: no target, server, reset, evidence, or test run
/// is touched by this command.
struct TKTestReliabilityCollectionPreflightResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let status: TKTestReliabilityCollectionPreflightStatus
    let writesEvidence: Bool
    let usesRuntime: Bool
    let eligibleForReliabilityGate: Bool
    let targetBindingDigest: String
    let supportedFlowCount: Int
    let runsPerSupportedFlow: Int
    let negativeControlCount: Int
    let plannedSampleCount: Int
    let flows: [TKTestReliabilityCollectionPreflightFlow]
    let blockerCodes: [String]

    init(
        targetBindingDigest: String,
        flows: [TKTestReliabilityCollectionPreflightFlow]
    ) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.test.reliability-collection-preflight"
        self.status = .readyToCollect
        self.writesEvidence = false
        self.usesRuntime = false
        self.eligibleForReliabilityGate = false
        self.targetBindingDigest = targetBindingDigest
        self.supportedFlowCount = flows.count
        self.runsPerSupportedFlow = 20
        self.negativeControlCount = 1
        self.plannedSampleCount = flows.reduce(1) { $0 + $1.plannedRunCount }
        self.flows = flows
        self.blockerCodes = []
    }
}

enum TKTestReliabilityCollectionError: Error, Equatable {
    case invalidCollection
}

func buildTritonTestReliabilityCollectionPreflight(
    collectionPath: String
) throws -> TKTestReliabilityCollectionPreflightResponse {
    do {
        let collection = try decodeTritonTestReliabilityCollection(at: collectionPath)
        let evidenceRoot = try validateReliabilityCollectionMetadata(collection)
        let targetBindingDigest = try validateReliabilityCollectionTarget(collection.target)
        let validatedFlows = try collection.flows.map {
            try validateReliabilityCollectionFlow(
                $0,
                target: collection.target,
                evidenceRoot: evidenceRoot,
                requiresTwentySlots: true
            )
        }
        try validateReliabilityCollectionFlowSet(collection.flows)
        try validateReliabilityCollectionNegativeControls(
            collection.negativeControls,
            supportedFlowIDs: Set(collection.flows.map(\.flowID)),
            supportedPlanDigests: Set(validatedFlows.map(\.planDigest)),
            target: collection.target,
            evidenceRoot: evidenceRoot
        )

        let flows = validatedFlows.enumerated().map { index, validated in
            TKTestReliabilityCollectionPreflightFlow(
                flowID: String(format: "flow_%03d", index + 1),
                plannedRunCount: 20,
                planDigest: validated.planDigest
            )
        }
        return TKTestReliabilityCollectionPreflightResponse(
            targetBindingDigest: targetBindingDigest,
            flows: flows
        )
    } catch let error as TKTestReliabilityCollectionError {
        throw error
    } catch {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
}

func testReliabilityCollectionErrorDetail(
    _ error: TKTestReliabilityCollectionError
) -> TKCLIErrorDetail {
    switch error {
    case .invalidCollection:
        return TKCLIErrorDetail(
            code: "invalid_reliability_collection",
            message: "Reliability collection must use the supported private preflight schema.",
            hint: "Declare three imported iOS Simulator flows with twenty fresh slots each, one negative control, and a canonical target binding."
        )
    }
}

private struct TKTestReliabilityValidatedCollectionFlow {
    let planDigest: String
}

private func decodeTritonTestReliabilityCollection(
    at path: String
) throws -> TKTestReliabilityCollection {
    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let collection = try? JSONDecoder().decode(TKTestReliabilityCollection.self, from: data),
          collection.schemaVersion == 1,
          collection.kind == "triton.test.reliability-collection" else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
    return collection
}

private func validateReliabilityCollectionMetadata(
    _ collection: TKTestReliabilityCollection
) throws -> URL {
    guard collection.flows.count == 3,
          collection.negativeControls.count == 1,
          collection.evidenceRoot.hasPrefix("/") else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }

    let root = URL(fileURLWithPath: collection.evidenceRoot, isDirectory: true)
        .standardizedFileURL
    let parent = root.deletingLastPathComponent()
    var parentIsDirectory: ObjCBool = false
    guard !FileManager.default.fileExists(atPath: root.path),
          FileManager.default.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory),
          parentIsDirectory.boolValue else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
    return root
}

private func validateReliabilityCollectionTarget(
    _ target: TKTestReliabilityCollectionTarget
) throws -> String {
    guard let uuid = UUID(uuidString: target.simulatorUDID),
          uuid.uuidString == target.simulatorUDID,
          !target.bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }

    let canonicalID = TKIOSSimulatorRuntimeTargetID(
        simulatorUDID: uuid.uuidString,
        bundleIdentifier: target.bundleID
    )
    let bindingDigest = fnv1a64Hex(Data(canonicalID.utf8))
    guard target.id == canonicalID,
          target.bindingDigest == bindingDigest,
          isFNV1a64Digest(target.bindingDigest) else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
    return bindingDigest
}

private func validateReliabilityCollectionFlowSet(
    _ flows: [TKTestReliabilityCollectionFlow]
) throws {
    let ids = flows.map(\.flowID)
    guard Set(ids).count == ids.count,
          ids.allSatisfy(isReliabilityCollectionIdentifier) else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
}

private func validateReliabilityCollectionNegativeControls(
    _ controls: [TKTestReliabilityCollectionNegativeControl],
    supportedFlowIDs: Set<String>,
    supportedPlanDigests: Set<String>,
    target: TKTestReliabilityCollectionTarget,
    evidenceRoot: URL
) throws {
    guard controls.count == 1,
          let control = controls.first,
          !supportedFlowIDs.contains(control.flowID),
          isReliabilityCollectionIdentifier(control.flowID),
          control.expectedOutcome == "nonpassed",
          control.slot == 1 else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }

    let planDigest = try validateReliabilityCollectionPlan(
        path: control.plan,
        expectedDigest: control.expectedPlanDigest,
        target: target
    )
    guard !supportedPlanDigests.contains(planDigest),
          isReliabilityCollectionIdentifier(control.initialStateID),
          isReliabilityCollectionIdentifier(control.resetRecipeID),
          reliabilityCollectionEvidenceReservation(
              root: evidenceRoot,
              flowID: control.flowID,
              slot: control.slot
          ) != nil else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
}

private func validateReliabilityCollectionFlow(
    _ flow: TKTestReliabilityCollectionFlow,
    target: TKTestReliabilityCollectionTarget,
    evidenceRoot: URL,
    requiresTwentySlots: Bool
) throws -> TKTestReliabilityValidatedCollectionFlow {
    guard isReliabilityCollectionIdentifier(flow.flowID),
          isReliabilityCollectionIdentifier(flow.initialStateID),
          isReliabilityCollectionIdentifier(flow.resetRecipeID),
          !flow.slots.isEmpty else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
    if requiresTwentySlots {
        guard flow.slots == Array(1...20) else {
            throw TKTestReliabilityCollectionError.invalidCollection
        }
    }

    let planDigest = try validateReliabilityCollectionPlan(
        path: flow.plan,
        expectedDigest: flow.expectedPlanDigest,
        target: target
    )
    let reservations = flow.slots.compactMap {
        reliabilityCollectionEvidenceReservation(root: evidenceRoot, flowID: flow.flowID, slot: $0)
    }
    guard reservations.count == flow.slots.count,
          Set(reservations).count == reservations.count else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
    return TKTestReliabilityValidatedCollectionFlow(planDigest: planDigest)
}

private func validateReliabilityCollectionPlan(
    path: String,
    expectedDigest: String,
    target: TKTestReliabilityCollectionTarget
) throws -> String {
    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          isFNV1a64Digest(expectedDigest),
          let yaml = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8),
          let plan = try? validateTritonTestContract(yaml: yaml, inputPath: path),
          plan.device.platform == "ios-simulator",
          plan.settings.strict,
          plan.settings.retry.count == 0,
          plan.app.bundleId == target.bundleID,
          let provenance = plan.provenance,
          provenance.sourceKind == "triton.testrec.compiled-contract",
          ["ios", "ios-simulator"].contains(provenance.sourcePlatform),
          let normalizedData = try? prettyEncodedData(plan) else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
    let digest = fnv1a64Hex(normalizedData)
    guard digest == expectedDigest else {
        throw TKTestReliabilityCollectionError.invalidCollection
    }
    return digest
}

private func reliabilityCollectionEvidenceReservation(
    root: URL,
    flowID: String,
    slot: Int
) -> String? {
    guard slot > 0 else { return nil }
    let relativePath = "\(flowID)/sample-\(String(format: "%03d", slot)).tritonevidence"
    let url = root.appendingPathComponent(relativePath, isDirectory: true).standardizedFileURL
    guard url.path.hasPrefix(root.path + "/") else { return nil }
    return url.path
}

private func isReliabilityCollectionIdentifier(_ value: String) -> Bool {
    value.range(
        of: #"^[a-z0-9][a-z0-9-]{0,63}$"#,
        options: .regularExpression
    ) != nil
}

private func isFNV1a64Digest(_ value: String) -> Bool {
    value.range(of: #"^[0-9a-f]{16}$"#, options: .regularExpression) != nil
}
