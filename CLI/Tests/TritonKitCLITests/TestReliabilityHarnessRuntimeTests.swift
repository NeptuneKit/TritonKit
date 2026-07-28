import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("SP-140 receipt-backed reliability harness")
struct TestReliabilityHarnessRuntimeTests {
    @Test("reserve atomically freezes normalized plans instead of retaining mutable YAML references")
    func reserveFreezesNormalizedPlans() throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collectionURL = try fixture.writeCollection()

        let reservation = try reserveTritonTestReliabilityCollection(collectionPath: collectionURL.path)
        let receiptURL = fixture.evidenceRoot.appendingPathComponent("collection-receipt.json")
        let receipt = try JSONDecoder().decode(
            TKTestReliabilityCollectionReceipt.self,
            from: Data(contentsOf: receiptURL)
        )

        #expect(reservation.ok)
        #expect(reservation.kind == "triton.test.reliability-reserve")
        #expect(reservation.plannedSampleCount == 61)
        #expect(receipt.flows.flatMap(\.slots).count == 61)
        #expect(receipt.flows.filter { $0.classification == .supported }.flatMap(\.slots).count == 60)
        #expect(receipt.flows.filter { $0.classification == .negativeControl }.flatMap(\.slots).count == 1)
        #expect(receipt.flows.allSatisfy { $0.planDigest == fnv1a64Hex(try! prettyEncodedData($0.normalizedPlan)) })
        let receiptText = try String(contentsOf: receiptURL, encoding: .utf8)
        #expect(!receiptText.contains(fixture.root.path))

        let frozenPlan = try #require(receipt.flows.first { $0.flowID == "flow_001" })
        try fixture.rewritePlan(named: "alpha", visibleText: "Changed after reserve")
        let reloaded = try JSONDecoder().decode(
            TKTestReliabilityCollectionReceipt.self,
            from: Data(contentsOf: receiptURL)
        )
        let reloadedFrozenPlan = try #require(reloaded.flows.first { $0.flowID == "flow_001" })
        #expect(reloadedFrozenPlan.normalizedPlan == frozenPlan.normalizedPlan)
        #expect(reloadedFrozenPlan.planDigest == frozenPlan.planDigest)
    }

    @Test("live target preflight accepts only one exact receipt-bound target")
    func liveTargetPreflightRejectsEveryFallbackShape() throws {
        let udid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
        let bundleID = "com.private.exacttarget"
        let targetID = TKIOSSimulatorRuntimeTargetID(
            simulatorUDID: udid,
            bundleIdentifier: bundleID
        )
        let receiptTarget = TKTestReliabilityCollectionTarget(
            id: targetID,
            simulatorUDID: udid,
            bundleID: bundleID,
            bindingDigest: fnv1a64Hex(Data(targetID.utf8))
        )
        let exact = TKTargetSummary(
            id: targetID,
            transport: "ios-simulator",
            connected: true,
            latestHierarchyAvailable: true,
            bundleIdentifier: bundleID,
            simulatorUDID: udid,
            platform: "ios"
        )
        let mismatches: [TKTargetSummary] = [
            TKTargetSummary(
                id: TKIOSSimulatorRuntimeTargetID(
                    simulatorUDID: udid,
                    bundleIdentifier: "com.private.other"
                ),
                transport: "ios-simulator",
                connected: true,
                latestHierarchyAvailable: true,
                bundleIdentifier: "com.private.other",
                simulatorUDID: udid,
                platform: "ios"
            ),
            TKTargetSummary(
                id: targetID,
                transport: "ios-simulator",
                connected: true,
                latestHierarchyAvailable: true,
                bundleIdentifier: nil,
                simulatorUDID: udid,
                platform: "ios"
            ),
            TKTargetSummary(
                id: targetID,
                transport: "ios-simulator",
                connected: true,
                latestHierarchyAvailable: true,
                bundleIdentifier: bundleID,
                simulatorUDID: udid,
                platform: "android"
            ),
            TKTargetSummary(
                id: targetID,
                transport: "ios-simulator",
                connected: false,
                latestHierarchyAvailable: false,
                bundleIdentifier: bundleID,
                simulatorUDID: udid,
                platform: "ios"
            ),
        ]

        #expect(try resolveReliabilityHarnessExactRuntimeTarget(
            receiptTarget: receiptTarget,
            targets: [exact]
        ) == exact)
        for mismatch in mismatches {
            #expect(throws: TKTestReliabilityHarnessError.invalidSampleRequest) {
                _ = try resolveReliabilityHarnessExactRuntimeTarget(
                    receiptTarget: receiptTarget,
                    targets: [mismatch]
                )
            }
        }
        #expect(throws: TKTestReliabilityHarnessError.invalidSampleRequest) {
            _ = try resolveReliabilityHarnessExactRuntimeTarget(
                receiptTarget: receiptTarget,
                targets: [exact, exact]
            )
        }
    }

    @Test("reserve rejects lower- and mixed-case Simulator UUID fields before creating a private receipt")
    func reserveRejectsNonCanonicalSimulatorUUIDCasing() throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collectionURL = try fixture.writeCollection()

        for candidate in [
            fixture.simulatorUDID.lowercased(),
            "A0b1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
        ] {
            try replaceHarnessCollectionTargetUDID(at: collectionURL, with: candidate)
            #expect(throws: TKTestReliabilityHarnessError.invalidCollectionReceiptInput) {
                _ = try reserveTritonTestReliabilityCollection(collectionPath: collectionURL.path)
            }
            #expect(!FileManager.default.fileExists(atPath: fixture.evidenceRoot.path))
        }
    }
}

private func replaceHarnessCollectionTargetUDID(at url: URL, with udid: String) throws {
    guard var collection = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
          var target = collection["target"] as? [String: Any] else {
        throw RuntimeError("Expected a reliability collection target")
    }
    target["simulatorUDID"] = udid
    collection["target"] = target
    try JSONSerialization.data(withJSONObject: collection, options: [.sortedKeys]).write(to: url, options: .atomic)
}

private final class ReliabilityHarnessFixture {
    let root: URL
    let evidenceRoot: URL
    let simulatorUDID = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
    let bundleID = "com.private.harnessfixture"

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-private-harness-\(UUID().uuidString)", isDirectory: true)
        evidenceRoot = root.appendingPathComponent("private-evidence-root", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["alpha", "beta", "gamma", "negative"] {
            try writePlan(named: name, visibleText: "Visible \(name)")
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeCollection() throws -> URL {
        let target = TKTestReliabilityCollectionTarget(
            id: targetID,
            simulatorUDID: simulatorUDID,
            bundleID: bundleID,
            bindingDigest: fnv1a64Hex(Data(targetID.utf8))
        )
        let flows = try ["alpha", "beta", "gamma"].map { name in
            TKTestReliabilityCollectionFlow(
                flowID: "private-flow-\(name)",
                plan: planURL(named: name).path,
                expectedPlanDigest: try planDigest(named: name),
                initialStateID: "private-initial-state-\(name)",
                resetRecipeID: "private-reset-recipe-\(name)",
                slots: Array(1...20)
            )
        }
        let negative = TKTestReliabilityCollectionNegativeControl(
            flowID: "private-negative-control",
            plan: planURL(named: "negative").path,
            expectedPlanDigest: try planDigest(named: "negative"),
            initialStateID: "private-initial-state-negative",
            resetRecipeID: "private-reset-recipe-negative",
            slot: 1,
            expectedOutcome: "nonpassed",
            expectedFailureType: "assert_visible_failed"
        )
        let collection = TKTestReliabilityCollection(
            schemaVersion: 1,
            kind: "triton.test.reliability-collection",
            target: target,
            evidenceRoot: evidenceRoot.path,
            flows: flows,
            negativeControls: [negative]
        )
        let url = root.appendingPathComponent("private-collection.json")
        try prettyEncodedData(collection).write(to: url, options: .atomic)
        return url
    }

    func rewritePlan(named name: String, visibleText: String) throws {
        try writePlan(named: name, visibleText: visibleText)
    }

    private var targetID: String {
        TKIOSSimulatorRuntimeTargetID(simulatorUDID: simulatorUDID, bundleIdentifier: bundleID)
    }

    private func planURL(named name: String) -> URL {
        root.appendingPathComponent("\(name).tritontest.yaml")
    }

    private func planDigest(named name: String) throws -> String {
        let yaml = try String(contentsOf: planURL(named: name), encoding: .utf8)
        let normalized = try validateTritonTestContract(yaml: yaml, inputPath: planURL(named: name).path)
        return fnv1a64Hex(try prettyEncodedData(normalized))
    }

    private func writePlan(named name: String, visibleText: String) throws {
        let yaml = """
        version: 1
        name: private-\(name)
        app:
          bundleId: \(bundleID)
        device:
          platform: ios-simulator
        settings:
          strict: true
          timeoutMs: 5000
          retry:
            count: 0
            intervalMs: 250
        provenance:
          importerVersion: 1
          sourceKind: triton.testrec.compiled-contract
          sourcePlatform: ios
          contractRef:
            path: compiled-contract.json
            byteCount: 42
            digestAlgorithm: fnv1a64
            digest: 0123456789abcdef
        steps:
          - launch: {}
          - assertVisible:
              text: \(visibleText)
        """
        try yaml.write(to: planURL(named: name), atomically: true, encoding: .utf8)
    }
}
