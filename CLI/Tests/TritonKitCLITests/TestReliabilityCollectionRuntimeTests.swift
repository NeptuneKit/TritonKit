import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("SP-136 reliability collection preflight")
struct TestReliabilityCollectionRuntimeTests {
    @Test("preflight freezes three imported Simulator flows without exposing private collection data")
    func preflightFreezesPrivateCollectionWithoutExposingInputs() throws {
        let fixture = try ReliabilityCollectionFixture()
        defer { fixture.cleanup() }
        let collection = try fixture.writeCollection(fixture.validCollection())

        let response = try buildTritonTestReliabilityCollectionPreflight(collectionPath: collection.path)

        #expect(response.ok)
        #expect(response.kind == "triton.test.reliability-collection-preflight")
        #expect(response.status == .readyToCollect)
        #expect(response.writesEvidence == false)
        #expect(response.usesRuntime == false)
        #expect(response.eligibleForReliabilityGate == false)
        #expect(response.supportedFlowCount == 3)
        #expect(response.runsPerSupportedFlow == 20)
        #expect(response.negativeControlCount == 1)
        #expect(response.plannedSampleCount == 61)
        #expect(response.flows.map(\.flowID) == ["flow_001", "flow_002", "flow_003"])
        #expect(response.flows.allSatisfy { $0.plannedRunCount == 20 })
        #expect(response.flows.allSatisfy { $0.planDigest.count == 16 })
        #expect(response.targetBindingDigest.count == 16)
        #expect(response.blockerCodes.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.evidenceRoot.path))

        let encoded = try encodeJSON(response)
        for privateValue in fixture.privateValues + [collection.path] {
            #expect(!encoded.contains(privateValue))
        }
    }

    @Test("preflight fails closed for target plan slot negative-control and evidence-root drift")
    func preflightFailsClosedForCollectionDrift() throws {
        let fixture = try ReliabilityCollectionFixture()
        defer { fixture.cleanup() }
        let valid = fixture.validCollection()

        let invalidTarget = TKTestReliabilityCollectionTarget(
            id: "local",
            simulatorUDID: fixture.simulatorUDID,
            bundleID: fixture.bundleID,
            bindingDigest: fixture.targetBindingDigest
        )
        let lowerCaseTarget = TKTestReliabilityCollectionTarget(
            id: fixture.targetID,
            simulatorUDID: fixture.simulatorUDID.lowercased(),
            bundleID: fixture.bundleID,
            bindingDigest: fixture.targetBindingDigest
        )
        let mixedCaseTarget = TKTestReliabilityCollectionTarget(
            id: fixture.targetID,
            simulatorUDID: "A0b1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            bundleID: fixture.bundleID,
            bindingDigest: fixture.targetBindingDigest
        )
        let duplicateSlots = TKTestReliabilityCollectionFlow(
            flowID: valid.flows[0].flowID,
            plan: valid.flows[0].plan,
            expectedPlanDigest: valid.flows[0].expectedPlanDigest,
            initialStateID: valid.flows[0].initialStateID,
            resetRecipeID: valid.flows[0].resetRecipeID,
            slots: Array(1...19) + [19]
        )
        let nonImportedPlan = try fixture.plan(name: "private-unimported", imported: false)
        let nonImportedFlow = TKTestReliabilityCollectionFlow(
            flowID: valid.flows[1].flowID,
            plan: nonImportedPlan.url.path,
            expectedPlanDigest: nonImportedPlan.digest,
            initialStateID: valid.flows[1].initialStateID,
            resetRecipeID: valid.flows[1].resetRecipeID,
            slots: valid.flows[1].slots
        )
        let digestDrift = TKTestReliabilityCollectionFlow(
            flowID: valid.flows[2].flowID,
            plan: valid.flows[2].plan,
            expectedPlanDigest: "0000000000000000",
            initialStateID: valid.flows[2].initialStateID,
            resetRecipeID: valid.flows[2].resetRecipeID,
            slots: valid.flows[2].slots
        )
        let reusedSupportedPlanControl = TKTestReliabilityCollectionNegativeControl(
            flowID: "private-negative-control",
            plan: valid.flows[0].plan,
            expectedPlanDigest: valid.flows[0].expectedPlanDigest,
            initialStateID: "private-negative-state",
            resetRecipeID: "private-negative-reset-recipe",
            slot: 1,
            expectedOutcome: "nonpassed",
            expectedFailureType: "assert_visible_failed"
        )
        let invalidFailureTypeControl = TKTestReliabilityCollectionNegativeControl(
            flowID: valid.negativeControls[0].flowID,
            plan: valid.negativeControls[0].plan,
            expectedPlanDigest: valid.negativeControls[0].expectedPlanDigest,
            initialStateID: valid.negativeControls[0].initialStateID,
            resetRecipeID: valid.negativeControls[0].resetRecipeID,
            slot: 1,
            expectedOutcome: "nonpassed",
            expectedFailureType: "launch_failed"
        )
        let writePlan = try fixture.plan(
            name: "private-negative-write",
            imported: true,
            includeWritePrimitive: true
        )
        let writePrimitiveControl = TKTestReliabilityCollectionNegativeControl(
            flowID: valid.negativeControls[0].flowID,
            plan: writePlan.url.path,
            expectedPlanDigest: writePlan.digest,
            initialStateID: valid.negativeControls[0].initialStateID,
            resetRecipeID: valid.negativeControls[0].resetRecipeID,
            slot: 1,
            expectedOutcome: "nonpassed",
            expectedFailureType: "assert_visible_failed"
        )
        let optionalLaunchPlan = try fixture.plan(
            name: "private-negative-optional-launch",
            imported: true,
            optionalLaunch: true
        )
        let optionalLaunchControl = TKTestReliabilityCollectionNegativeControl(
            flowID: valid.negativeControls[0].flowID,
            plan: optionalLaunchPlan.url.path,
            expectedPlanDigest: optionalLaunchPlan.digest,
            initialStateID: valid.negativeControls[0].initialStateID,
            resetRecipeID: valid.negativeControls[0].resetRecipeID,
            slot: 1,
            expectedOutcome: "nonpassed",
            expectedFailureType: "assert_visible_failed"
        )

        let variants = [
            fixture.collection(from: valid, target: invalidTarget),
            fixture.collection(from: valid, target: lowerCaseTarget),
            fixture.collection(from: valid, target: mixedCaseTarget),
            fixture.collection(from: valid, flows: Array(valid.flows.prefix(2))),
            fixture.collection(from: valid, flows: valid.flows + [valid.flows[0]]),
            fixture.collection(from: valid, flows: [duplicateSlots, valid.flows[1], valid.flows[2]]),
            fixture.collection(from: valid, flows: [valid.flows[0], nonImportedFlow, valid.flows[2]]),
            fixture.collection(from: valid, flows: [valid.flows[0], valid.flows[1], digestDrift]),
            fixture.collection(from: valid, negativeControls: []),
            fixture.collection(from: valid, negativeControls: [reusedSupportedPlanControl]),
            fixture.collection(from: valid, negativeControls: [invalidFailureTypeControl]),
            fixture.collection(from: valid, negativeControls: [writePrimitiveControl]),
            fixture.collection(from: valid, negativeControls: [optionalLaunchControl]),
        ]

        for (index, variant) in variants.enumerated() {
            let collection = try fixture.writeCollection(variant, name: "private-invalid-\(index)")
            #expect(throws: TKTestReliabilityCollectionError.self) {
                _ = try buildTritonTestReliabilityCollectionPreflight(collectionPath: collection.path)
            }
        }

        try FileManager.default.createDirectory(at: fixture.evidenceRoot, withIntermediateDirectories: true)
        let existingRoot = try fixture.writeCollection(valid, name: "private-existing-root")
        #expect(throws: TKTestReliabilityCollectionError.self) {
            _ = try buildTritonTestReliabilityCollectionPreflight(collectionPath: existingRoot.path)
        }
    }

    @Test("preflight schema and capabilities remain offline and point only at placeholders")
    func preflightSchemaAndCapabilitiesRemainOffline() throws {
        let schema = try #require(commandSchemas().first { $0.name == "test" })
        let preflight = try #require(schema.subcommands.first { $0.name == "reliability-preflight" })
        let output = try #require(schema.outputContracts.first { $0.selector == "test.reliability-collection-preflight" })
        let capabilities = Dictionary(uniqueKeysWithValues: runtimeCapabilities(
            host: "127.0.0.1",
            port: 19421,
            serverReachable: false,
            connected: false
        ).map { ($0.name, $0) })
        let existingGate = try #require(capabilities["test-reliability-gate"])
        let collectionPreflight = try #require(capabilities["test-reliability-collection-preflight"])
        let reserve = try #require(capabilities["test-reliability-reserve"])
        let sample = try #require(capabilities["test-reliability-sample"])
        let reserveSchema = try #require(schema.subcommands.first { $0.name == "reliability-reserve" })
        let sampleSchema = try #require(schema.subcommands.first { $0.name == "reliability-sample" })
        let reserveOutput = try #require(schema.outputContracts.first { $0.selector == "test.reliability-reserve" })
        let sampleOutput = try #require(schema.outputContracts.first { $0.selector == "test.reliability-sample" })

        #expect(schema.runtimeScope.contains("reliability-preflight"))
        #expect(schema.providedCapabilities.contains("test-reliability-gate"))
        #expect(schema.providedCapabilities.contains("test-reliability-collection-preflight"))
        #expect(schema.providedCapabilities.contains("test-reliability-reserve"))
        #expect(schema.providedCapabilities.contains("test-reliability-sample"))
        #expect(preflight.requiredOptions == ["--collection"])
        #expect(preflight.outputSelectors == ["test.reliability-collection-preflight"])
        #expect(preflight.failureCodes == ["missing_required_field", "invalid_reliability_collection", "test_reliability_collection_preflight_failed"])
        #expect(output.kind == "test-reliability-collection-preflight")
        #expect(reserveSchema.requiredOptions == ["--collection"])
        #expect(reserveSchema.outputSelectors == ["test.reliability-reserve"])
        #expect(reserveSchema.sideEffect == "private-receipt-write")
        #expect(sampleSchema.requiredOptions == ["--collection-receipt", "--expect-receipt-sha256", "--flow", "--slot", "--reset-receipt", "--target", "--confirm"])
        #expect(sampleSchema.outputSelectors == ["test.reliability-sample"])
        #expect(sampleSchema.requiresServer)
        #expect(sampleSchema.requiresTarget)
        #expect(sampleSchema.requiresConfirmation)
        #expect(sampleSchema.sideEffect == "runtime-execution-private-evidence-write")
        #expect(sampleSchema.optionOverrides.first { $0.name == "--target" }?.required == true)
        #expect(sampleSchema.optionOverrides.first { $0.name == "--expect-receipt-sha256" }?.type == "SHA256")
        #expect(sampleSchema.optionOverrides.first { $0.name == "--expect-receipt-sha256" }?.required == true)
        #expect(reserveOutput.kind == "test-reliability-reserve")
        #expect(reserveOutput.fields.first { $0.name == "receiptFile" }?.description.contains("never an absolute") == true)
        #expect(reserveOutput.fields.first { $0.name == "receiptDigest" }?.description.contains("Legacy FNV") == true)
        #expect(reserveOutput.fields.first { $0.name == "receiptSha256" }?.description.contains("exact raw") == true)
        #expect(sampleOutput.kind == "test-reliability-sample")
        #expect(sampleOutput.fields.first { $0.name == "targetBindingDigest" }?.description.contains("raw target stays private") == true)
        #expect(existingGate.supported)
        #expect(existingGate.group == "test")
        #expect(existingGate.requiredBy == ["test"])
        #expect(existingGate.nextAction?.command == "test")
        #expect(existingGate.nextAction?.args == ["reliability", "--samples", "<private.json>", "--json"])
        #expect(collectionPreflight.supported)
        #expect(collectionPreflight.group == "test")
        #expect(collectionPreflight.requiredBy == ["test"])
        #expect(collectionPreflight.nextAction?.command == "test")
        #expect(collectionPreflight.nextAction?.args == ["reliability-preflight", "--collection", "<private.json>", "--json"])
        #expect(collectionPreflight.nextAction?.requiresLongRunningProcess == false)
        #expect(collectionPreflight.evidence == ["stdout-json", "command-schema"])
        #expect(reserve.supported)
        #expect(reserve.group == "test")
        #expect(reserve.requiredBy == ["test"])
        #expect(reserve.nextAction?.command == "test")
        #expect(reserve.nextAction?.args == ["reliability-reserve", "--collection", "<private.json>", "--json"])
        #expect(reserve.nextAction?.requiresLongRunningProcess == false)
        #expect(reserve.evidence == ["stdout-json", "command-schema"])
        #expect(sample.supported)
        #expect(sample.group == "test")
        #expect(sample.requiredBy == ["test"])
        #expect(sample.nextAction?.command == "schema")
        #expect(sample.nextAction?.args == ["--command", "test", "--json"])
        #expect(sample.nextAction?.args.contains("--confirm") == false)
        #expect(sample.nextAction?.requiresLongRunningProcess == false)
        #expect(sample.evidence == ["stdout-json", "command-schema", "evidence-bundle", "test.normalized-plan"])
    }

    @Test("preflight failure envelope is stable and never interpolates collection input")
    func preflightFailureEnvelopeDoesNotInterpolatePrivateInput() throws {
        let fixture = try ReliabilityCollectionFixture()
        defer { fixture.cleanup() }
        let detail = testReliabilityCollectionErrorDetail(.invalidCollection)
        let encoded = try encodeJSON(TKCLIErrorResponse(error: detail))

        #expect(detail.code == "invalid_reliability_collection")
        #expect(!encoded.contains(fixture.root.path))
        #expect(!encoded.contains(fixture.simulatorUDID))
        #expect(!encoded.contains(fixture.bundleID))
        #expect(!encoded.contains("private-flow-alpha"))
        #expect(!encoded.contains("private-reset-recipe"))
    }
}

private final class ReliabilityCollectionFixture {
    let root: URL
    let evidenceRoot: URL
    let simulatorUDID = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
    let bundleID = "com.private.collectionfixture"

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-private-collection-\(UUID().uuidString)", isDirectory: true)
        evidenceRoot = root.appendingPathComponent("private-evidence-root", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var targetBindingDigest: String {
        fnv1a64Hex(Data(targetID.utf8))
    }

    var targetID: String {
        TKIOSSimulatorRuntimeTargetID(simulatorUDID: simulatorUDID, bundleIdentifier: bundleID)
    }

    var privateValues: [String] {
        [
            root.path,
            evidenceRoot.path,
            simulatorUDID,
            bundleID,
            targetID,
            "private-flow-alpha",
            "private-reset-recipe",
            "Private Visible Label",
        ]
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func validCollection() -> TKTestReliabilityCollection {
        let alpha = try! plan(name: "private-alpha", imported: true)
        let beta = try! plan(name: "private-beta", imported: true)
        let gamma = try! plan(name: "private-gamma", imported: true)
        let negative = try! plan(name: "private-negative", imported: true)
        let target = TKTestReliabilityCollectionTarget(
            id: targetID,
            simulatorUDID: simulatorUDID,
            bundleID: bundleID,
            bindingDigest: targetBindingDigest
        )
        let flows = [
            flow(id: "private-flow-alpha", plan: alpha),
            flow(id: "private-flow-beta", plan: beta),
            flow(id: "private-flow-gamma", plan: gamma),
        ]
        let negativeControl = TKTestReliabilityCollectionNegativeControl(
            flowID: "private-negative-control",
            plan: negative.url.path,
            expectedPlanDigest: negative.digest,
            initialStateID: "private-negative-state",
            resetRecipeID: "private-negative-reset-recipe",
            slot: 1,
            expectedOutcome: "nonpassed",
            expectedFailureType: "assert_visible_failed"
        )
        return TKTestReliabilityCollection(
            schemaVersion: 1,
            kind: "triton.test.reliability-collection",
            target: target,
            evidenceRoot: evidenceRoot.path,
            flows: flows,
            negativeControls: [negativeControl]
        )
    }

    func collection(
        from base: TKTestReliabilityCollection,
        target: TKTestReliabilityCollectionTarget? = nil,
        flows: [TKTestReliabilityCollectionFlow]? = nil,
        negativeControls: [TKTestReliabilityCollectionNegativeControl]? = nil
    ) -> TKTestReliabilityCollection {
        TKTestReliabilityCollection(
            schemaVersion: base.schemaVersion,
            kind: base.kind,
            target: target ?? base.target,
            evidenceRoot: base.evidenceRoot,
            flows: flows ?? base.flows,
            negativeControls: negativeControls ?? base.negativeControls
        )
    }

    func writeCollection(_ collection: TKTestReliabilityCollection, name: String = "private-collection") throws -> URL {
        let url = root.appendingPathComponent("\(name)-\(UUID().uuidString).json")
        try prettyEncodedData(collection).write(to: url, options: .atomic)
        return url
    }

    func plan(
        name: String,
        imported: Bool,
        includeWritePrimitive: Bool = false,
        optionalLaunch: Bool = false
    ) throws -> (url: URL, digest: String) {
        let url = root.appendingPathComponent("\(name).tritontest.yaml")
        let provenance = imported ? """
        provenance:
          importerVersion: 1
          sourceKind: triton.testrec.compiled-contract
          sourcePlatform: ios
          contractRef:
            path: compiled-contract.json
            byteCount: 42
            digestAlgorithm: fnv1a64
            digest: 0123456789abcdef
        """ : ""
        let writePrimitive = includeWritePrimitive ? """
          - input:
              text: Private write primitive
        """ : ""
        let launchStep = optionalLaunch ? """
          - optional: true
            launch: {}
        """ : """
          - launch: {}
        """
        let yaml = """
        version: 1
        name: \(name)
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
        \(provenance)
        steps:
        \(launchStep)
        \(writePrimitive)
          - assertVisible:
              text: Private Visible Label
        """
        try yaml.write(to: url, atomically: true, encoding: .utf8)
        let normalized = try validateTritonTestContract(yaml: yaml, inputPath: url.path)
        return (url, fnv1a64Hex(try prettyEncodedData(normalized)))
    }

    private func flow(
        id: String,
        plan: (url: URL, digest: String)
    ) -> TKTestReliabilityCollectionFlow {
        TKTestReliabilityCollectionFlow(
            flowID: id,
            plan: plan.url.path,
            expectedPlanDigest: plan.digest,
            initialStateID: "private-initial-state",
            resetRecipeID: "private-reset-recipe",
            slots: Array(1...20)
        )
    }
}
