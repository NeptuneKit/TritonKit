import ArgumentParser
import Dispatch
import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("SP-140 receipt-backed reliability harness")
struct TestReliabilityHarnessTests {
    @Test("reserve freezes distinct imported plans and atomically publishes one private receipt")
    func reserveFreezesCollection() throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }

        let collection = try fixture.writeCollection(fixture.validCollection())
        let response = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)

        #expect(response.ok)
        #expect(response.kind == "triton.test.reliability-reserve")
        #expect(response.supportedFlowCount == 3)
        #expect(response.plannedSampleCount == 61)
        #expect(response.targetBindingDigest == fixture.targetBindingDigest)
        #expect(FileManager.default.fileExists(
            atPath: fixture.evidenceRoot.appendingPathComponent("collection-receipt.json").path
        ))

        do {
            _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
            Issue.record("A second reserve must not overwrite the existing root or receipt")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .reservationAlreadyExists)
        }
    }

    @Test("concurrent reserve leaves exactly one immutable receipt and never enters runtime")
    func concurrentReserveHasOneWinner() throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collection = try fixture.writeCollection(fixture.validCollection())
        let results = HarnessReserveResults()
        let group = DispatchGroup()

        for _ in 0..<2 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                do {
                    results.recordSuccess(
                        try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
                    )
                } catch let error as TKTestReliabilityHarnessError {
                    results.recordHarnessError(error)
                } catch {
                    results.recordUnexpectedError()
                }
            }
        }
        group.wait()

        let snapshot = results.snapshot()
        #expect(snapshot.successes.count == 1)
        #expect(snapshot.harnessErrors == [.reservationAlreadyExists])
        #expect(snapshot.unexpectedErrorCount == 0)
        let receipt = try Data(contentsOf: fixture.evidenceRoot.appendingPathComponent("collection-receipt.json"))
        #expect(fnv1a64Hex(receipt) == snapshot.successes[0].receiptDigest)
    }

    @Test("reserve rejects plans whose semantic execution identity only differs in metadata")
    func reserveRejectsDuplicateExecutionIdentity() throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }

        var collection = fixture.validCollection()
        let semanticClone = try fixture.plan(name: "different-name", visibleText: "Alpha screen")
        let first = collection.flows[0]
        collection = fixture.collection(
            collection,
            flows: [
                first,
                TKTestReliabilityCollectionFlow(
                    flowID: "flow-beta",
                    plan: semanticClone.url.path,
                    expectedPlanDigest: semanticClone.digest,
                    initialStateID: "initial-beta",
                    resetRecipeID: "reset-beta",
                    slots: Array(1...20)
                ),
                collection.flows[2],
            ]
        )
        let path = try fixture.writeCollection(collection)

        do {
            _ = try reserveTritonTestReliabilityCollection(collectionPath: path.path)
            Issue.record("Execution-identity clones must fail closed")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .invalidCollectionReceiptInput)
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.evidenceRoot.path))
    }

    @Test("reserve rejects an imported plan without the canonical launch bootstrap")
    func reserveRejectsPlanWithoutLaunchBootstrap() throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }

        var collection = fixture.validCollection()
        let noLaunch = try fixture.planWithoutLaunch(name: "no-launch", visibleText: "No launch")
        let original = collection.flows[0]
        collection = fixture.collection(
            collection,
            flows: [
                TKTestReliabilityCollectionFlow(
                    flowID: original.flowID,
                    plan: noLaunch.url.path,
                    expectedPlanDigest: noLaunch.digest,
                    initialStateID: original.initialStateID,
                    resetRecipeID: original.resetRecipeID,
                    slots: original.slots
                ),
                collection.flows[1],
                collection.flows[2],
            ]
        )

        do {
            _ = try reserveTritonTestReliabilityCollection(
                collectionPath: try fixture.writeCollection(collection).path
            )
            Issue.record("A receipt plan must produce the runtime-target sidecar through launch")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .invalidCollectionReceiptInput)
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.evidenceRoot.path))
    }

    @Test("a self-consistent receipt outcome mutation fails before reset lookup, slot claim, or runner")
    func sampleRejectsTamperedFrozenOutcomeBeforeRunner() async throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collection = try fixture.writeCollection(fixture.validCollection())
        _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
        let receipt = fixture.evidenceRoot.appendingPathComponent("collection-receipt.json")
        let reset = try fixture.writeResetReceipt(receiptURL: receipt, flowID: "flow_001", slot: 1)
        try replaceReceiptFlowField(
            at: receipt,
            flowID: "flow_001",
            key: "expectedOutcome",
            value: "nonpassed"
        )

        let executor = HarnessFakeExecutor()
        do {
            _ = try await runTritonTestReliabilitySample(
                request: TKTestReliabilitySampleRequest(
                    collectionReceipt: receipt.path,
                    flow: "flow_001",
                    slot: 1,
                    resetReceipt: reset.path,
                    target: fixture.targetID,
                    host: "127.0.0.1",
                    port: 19421,
                    confirm: true
                ),
                executor: executor,
                targetResolver: fixture.targetResolver()
            )
            Issue.record("A receipt with a tampered supported outcome must fail closed")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .invalidReceipt)
        }
        #expect(executor.operations.isEmpty)
        #expect(executor.plans.isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: fixture.evidenceRoot.appendingPathComponent("flow_001").path
        ))
    }

    @Test("sample refuses missing confirmation before claiming a slot or invoking the runner")
    func sampleRequiresConfirmationBeforeAnyWriteOrExecution() async throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collection = try fixture.writeCollection(fixture.validCollection())
        _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
        let receipt = fixture.evidenceRoot.appendingPathComponent("collection-receipt.json")
        let reset = try fixture.writeResetReceipt(
            receiptURL: receipt,
            flowID: "flow_001",
            slot: 1
        )
        let executor = HarnessFakeExecutor()

        let request = TKTestReliabilitySampleRequest(
            collectionReceipt: receipt.path,
            flow: "flow_001",
            slot: 1,
            resetReceipt: reset.path,
            target: fixture.targetID,
            host: "127.0.0.1",
            port: 19421,
            confirm: false
        )
        let targetResolver = fixture.targetResolver()
        do {
            _ = try await runTritonTestReliabilitySample(
                request: request,
                executor: executor,
                targetResolver: targetResolver
            )
            Issue.record("Missing --confirm must fail before any primitive runs")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .confirmationRequired)
        }
        #expect(executor.operations.isEmpty)
        #expect(targetResolver.calls == 0)
        #expect(!FileManager.default.fileExists(
            atPath: fixture.evidenceRoot.appendingPathComponent("flow_001").path
        ))
    }

    @Test("confirmed sample executes only the receipt-frozen normalized plan and seals one slot")
    func sampleExecutesFrozenPlanAndWritesManifestSidecars() async throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let declaration = fixture.validCollection()
        let mutableSource = URL(fileURLWithPath: declaration.flows[0].plan)
        let collection = try fixture.writeCollection(declaration)
        _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
        let receipt = fixture.evidenceRoot.appendingPathComponent("collection-receipt.json")
        try fixture.rewritePlan(
            at: mutableSource,
            name: "mutated-after-reserve",
            visibleText: "Changed source after reserve"
        )
        let reset = try fixture.writeResetReceipt(receiptURL: receipt, flowID: "flow_001", slot: 1)
        let executor = HarnessFakeExecutor()
        let request = TKTestReliabilitySampleRequest(
            collectionReceipt: receipt.path,
            flow: "flow_001",
            slot: 1,
            resetReceipt: reset.path,
            target: fixture.targetID,
            host: "127.0.0.1",
            port: 19421,
            confirm: true
        )

        let targetResolver = fixture.targetResolver()
        let response = try await runTritonTestReliabilitySample(
            request: request,
            executor: executor,
            targetResolver: targetResolver
        )
        let evidence = fixture.evidenceRoot
            .appendingPathComponent("flow_001", isDirectory: true)
            .appendingPathComponent("sample-001.tritonevidence", isDirectory: true)
        let manifest = try JSONDecoder().decode(
            TKEvidenceManifest.self,
            from: Data(contentsOf: evidence.appendingPathComponent("manifest.json"))
        )

        #expect(response.ok)
        #expect(response.outcomeMatched)
        #expect(response.runStatus == .passed)
        #expect(executor.plans.count == 1)
        #expect(targetResolver.calls == 1)
        #expect(executor.plans[0].name == "alpha")
        #expect(executor.plans[0].steps[1].selector?.text == "Alpha screen")
        #expect(FileManager.default.fileExists(atPath: evidence.appendingPathComponent("reliability/binding.json").path))
        #expect(FileManager.default.fileExists(atPath: evidence.appendingPathComponent("reliability/reset-receipt.json").path))
        #expect(manifest.artifacts.contains { $0.kind == "test.reliability.binding" && $0.path == "reliability/binding.json" })
        #expect(manifest.artifacts.contains { $0.kind == "test.reliability.reset-receipt" && $0.path == "reliability/reset-receipt.json" })

        do {
            _ = try await runTritonTestReliabilitySample(
                request: request,
                executor: executor,
                targetResolver: fixture.targetResolver()
            )
            Issue.record("An already claimed slot must not be reused")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .slotAlreadyClaimed)
        }
        #expect(executor.plans.count == 1)
    }

    @Test("target endpoint and reset receipt mismatches fail before claiming a slot")
    func sampleRejectsMismatchesBeforeSlotClaim() async throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collection = try fixture.writeCollection(fixture.validCollection())
        _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
        let receipt = fixture.evidenceRoot.appendingPathComponent("collection-receipt.json")
        let validReset = try fixture.writeResetReceipt(receiptURL: receipt, flowID: "flow_001", slot: 1)
        let invalidReset = try fixture.writeResetReceipt(
            receiptURL: receipt,
            flowID: "flow_001",
            slot: 1,
            verified: false
        )
        let executor = HarnessFakeExecutor()

        let invalidHost = TKTestReliabilitySampleRequest(
            collectionReceipt: receipt.path,
            flow: "flow_001",
            slot: 1,
            resetReceipt: validReset.path,
            target: fixture.targetID,
            host: "localhost",
            port: 19421,
            confirm: true
        )
        do {
            _ = try await runTritonTestReliabilitySample(
                request: invalidHost,
                executor: executor,
                targetResolver: fixture.targetResolver()
            )
            Issue.record("Non-literal loopback must be rejected")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .invalidSampleRequest)
        }

        let invalidResetRequest = TKTestReliabilitySampleRequest(
            collectionReceipt: receipt.path,
            flow: "flow_001",
            slot: 1,
            resetReceipt: invalidReset.path,
            target: fixture.targetID,
            host: "127.0.0.1",
            port: 19421,
            confirm: true
        )
        do {
            _ = try await runTritonTestReliabilitySample(
                request: invalidResetRequest,
                executor: executor,
                targetResolver: fixture.targetResolver()
            )
            Issue.record("Unverified reset receipt must be rejected")
        } catch let error as TKTestReliabilityHarnessError {
            #expect(error == .invalidResetReceipt)
        }

        let fallbackRequest = TKTestReliabilitySampleRequest(
            collectionReceipt: receipt.path,
            flow: "flow_001",
            slot: 1,
            resetReceipt: validReset.path,
            target: fixture.targetID,
            host: "127.0.0.1",
            port: 19421,
            confirm: true
        )
        let mismatchedTargets: [(name: String, summary: TKTargetSummary)] = [
            (
                "same UDID with a different canonical id and bundle",
                fixture.runtimeTargetSummary(
                    id: TKIOSSimulatorRuntimeTargetID(
                        simulatorUDID: fixture.simulatorUDID,
                        bundleIdentifier: "com.private.otherapp"
                    ),
                    bundleIdentifier: "com.private.otherapp"
                )
            ),
            (
                "same canonical id with a missing bundle",
                fixture.runtimeTargetSummary(
                    id: fixture.targetID,
                    bundleIdentifier: nil
                )
            ),
            (
                "same canonical id with the wrong platform",
                fixture.runtimeTargetSummary(
                    id: fixture.targetID,
                    bundleIdentifier: fixture.bundleID,
                    platform: "android"
                )
            ),
            (
                "same canonical id disconnected",
                fixture.runtimeTargetSummary(
                    id: fixture.targetID,
                    bundleIdentifier: fixture.bundleID,
                    connected: false
                )
            ),
        ]
        for mismatch in mismatchedTargets {
            let resolver = HarnessTargetResolver(summary: mismatch.summary)
            do {
                _ = try await runTritonTestReliabilitySample(
                    request: fallbackRequest,
                    executor: executor,
                    targetResolver: resolver
                )
                Issue.record("A \(mismatch.name) must fail before slot claim")
            } catch let error as TKTestReliabilityHarnessError {
                #expect(error == .invalidSampleRequest)
            }
            #expect(resolver.calls == 1)
        }
        #expect(executor.operations.isEmpty)
        #expect(executor.plans.isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: fixture.evidenceRoot.appendingPathComponent("flow_001").path
        ))
    }

    @Test("an existing empty or populated slot is never reused, reset, or executed")
    func sampleRejectsExistingSlotWithoutOverwritingIt() async throws {
        for scenario in ["empty", "run", "manifest"] {
            let fixture = try ReliabilityHarnessFixture()
            defer { fixture.cleanup() }
            let collection = try fixture.writeCollection(fixture.validCollection())
            _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
            let receipt = fixture.evidenceRoot.appendingPathComponent("collection-receipt.json")
            let reset = try fixture.writeResetReceipt(receiptURL: receipt, flowID: "flow_001", slot: 1)
            let evidence = fixture.evidenceRoot
                .appendingPathComponent("flow_001", isDirectory: true)
                .appendingPathComponent("sample-001.tritonevidence", isDirectory: true)
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)

            var sentinel: URL?
            var original: Data?
            switch scenario {
            case "run":
                let run = evidence.appendingPathComponent("run", isDirectory: true)
                try FileManager.default.createDirectory(at: run, withIntermediateDirectories: false)
                let file = run.appendingPathComponent("sentinel.json")
                let bytes = Data("preserve-run".utf8)
                try bytes.write(to: file, options: .atomic)
                sentinel = file
                original = bytes
            case "manifest":
                let file = evidence.appendingPathComponent("manifest.json")
                let bytes = Data("preserve-manifest".utf8)
                try bytes.write(to: file, options: .atomic)
                sentinel = file
                original = bytes
            default:
                break
            }

            let executor = HarnessFakeExecutor()
            do {
                _ = try await runTritonTestReliabilitySample(
                    request: TKTestReliabilitySampleRequest(
                        collectionReceipt: receipt.path,
                        flow: "flow_001",
                        slot: 1,
                        resetReceipt: reset.path,
                        target: fixture.targetID,
                        host: "127.0.0.1",
                        port: 19421,
                        confirm: true
                    ),
                    executor: executor,
                    targetResolver: fixture.targetResolver()
                )
                Issue.record("Existing \(scenario) slot must fail closed")
            } catch let error as TKTestReliabilityHarnessError {
                #expect(error == .slotAlreadyClaimed)
            }

            #expect(executor.operations.isEmpty)
            if let sentinel, let original {
                #expect(try Data(contentsOf: sentinel) == original)
            } else {
                #expect(try FileManager.default.contentsOfDirectory(atPath: evidence.path).isEmpty)
            }
        }
    }

    @Test("receipt gate blocks tampered sidecars, manifest paths, supported failures, and a negative control that unexpectedly passes")
    func receiptGateValidatesPrivateSidecarsAndNegativeOutcome() async throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collection = try fixture.writeCollection(fixture.validCollection())
        _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
        let receipt = fixture.evidenceRoot.appendingPathComponent("collection-receipt.json")
        let executor = HarnessFakeExecutor()

        let positiveReset = try fixture.writeResetReceipt(receiptURL: receipt, flowID: "flow_001", slot: 1)
        _ = try await runTritonTestReliabilitySample(
            request: TKTestReliabilitySampleRequest(
                collectionReceipt: receipt.path,
                flow: "flow_001",
                slot: 1,
                resetReceipt: positiveReset.path,
                target: fixture.targetID,
                host: "127.0.0.1",
                port: 19421,
                confirm: true
            ),
            executor: executor,
            targetResolver: fixture.targetResolver()
        )
        let binding = fixture.evidenceRoot
            .appendingPathComponent("flow_001/sample-001.tritonevidence/reliability/binding.json")
        try Data("{}".utf8).write(to: binding, options: .atomic)
        let resetSidecar = fixture.evidenceRoot
            .appendingPathComponent("flow_001/sample-001.tritonevidence/reliability/reset-receipt.json")
        try replaceJSONField(at: resetSidecar, key: "kind", value: "tampered-reset-receipt")
        try replaceManifestArtifactPath(
            at: fixture.evidenceRoot.appendingPathComponent("flow_001/sample-001.tritonevidence/manifest.json"),
            kind: "test.reliability.binding",
            path: "reliability/not-the-binding.json"
        )

        let failingReset = try fixture.writeResetReceipt(receiptURL: receipt, flowID: "flow_002", slot: 1)
        let failedSupported = try await runTritonTestReliabilitySample(
            request: TKTestReliabilitySampleRequest(
                collectionReceipt: receipt.path,
                flow: "flow_002",
                slot: 1,
                resetReceipt: failingReset.path,
                target: fixture.targetID,
                host: "127.0.0.1",
                port: 19421,
                confirm: true
            ),
            executor: HarnessFailingExecutor(),
            targetResolver: fixture.targetResolver()
        )
        #expect(!failedSupported.ok)
        #expect(failedSupported.runStatus == .failed)

        let negativeReset = try fixture.writeResetReceipt(receiptURL: receipt, flowID: "negative_001", slot: 1)
        _ = try await runTritonTestReliabilitySample(
            request: TKTestReliabilitySampleRequest(
                collectionReceipt: receipt.path,
                flow: "negative_001",
                slot: 1,
                resetReceipt: negativeReset.path,
                target: fixture.targetID,
                host: "127.0.0.1",
                port: 19421,
                confirm: true
            ),
            executor: executor,
            targetResolver: fixture.targetResolver()
        )

        let report = try buildTritonTestReliabilityReceiptReport(collectionReceiptPath: receipt.path)
        #expect(report.gate.status == .blocked)
        #expect(report.gate.blockerCodes.contains("receipt_binding_invalid"))
        #expect((report.issueCounts["receipt_binding_sidecar_invalid"] ?? 0) >= 1)
        #expect((report.issueCounts["receipt_reset_sidecar_invalid"] ?? 0) >= 1)
        #expect((report.issueCounts["receipt_manifest_sidecars_invalid"] ?? 0) >= 1)
        #expect((report.issueCounts["supported_flow_nonpassed"] ?? 0) == 1)
        #expect((report.issueCounts["negative_control_passed"] ?? 0) == 1)
    }

    @Test("sample command emits one typed result before its business exit status")
    func sampleCommandOutputPreservesTypedBusinessResults() throws {
        let fixture = try ReliabilityHarnessFixture()
        defer { fixture.cleanup() }
        let collection = try fixture.writeCollection(fixture.validCollection())
        _ = try reserveTritonTestReliabilityCollection(collectionPath: collection.path)
        let receipt = try JSONDecoder().decode(
            TKTestReliabilityCollectionReceipt.self,
            from: Data(contentsOf: fixture.evidenceRoot.appendingPathComponent("collection-receipt.json"))
        )
        let supported = try #require(receipt.flows.first { $0.classification == .supported })
        let negative = try #require(receipt.flows.first { $0.classification == .negativeControl })
        let supportedSlot = try #require(supported.slots.first)
        let negativeSlot = try #require(negative.slots.first)

        let expectedNegative = TKTestReliabilitySampleResponse(
            flow: negative,
            slot: negativeSlot,
            targetBindingDigest: receipt.target.bindingDigest,
            resetEvidenceDigest: "0123456789abcdef",
            runStatus: .failed
        )
        var expectedNegativeOutput: [String] = []
        try emitTestReliabilitySampleResult(
            expectedNegative,
            format: .json,
            write: { expectedNegativeOutput.append($0) }
        )
        #expect(expectedNegativeOutput.count == 1)
        let expectedNegativeJSON = try #require(expectedNegativeOutput.first)
        let decodedExpectedNegative = try JSONDecoder().decode(
            TKTestReliabilitySampleResponse.self,
            from: Data(expectedNegativeJSON.utf8)
        )
        #expect(decodedExpectedNegative == expectedNegative)
        #expect(decodedExpectedNegative.ok)
        #expect(!expectedNegativeJSON.contains("\"error\""))

        let unexpectedResponses = [
            TKTestReliabilitySampleResponse(
                flow: supported,
                slot: supportedSlot,
                targetBindingDigest: receipt.target.bindingDigest,
                resetEvidenceDigest: "0123456789abcdef",
                runStatus: .failed
            ),
            TKTestReliabilitySampleResponse(
                flow: negative,
                slot: negativeSlot,
                targetBindingDigest: receipt.target.bindingDigest,
                resetEvidenceDigest: "0123456789abcdef",
                runStatus: .passed
            ),
        ]
        for response in unexpectedResponses {
            var output: [String] = []
            let exitedWithFailure: Bool
            do {
                try emitTestReliabilitySampleResult(
                    response,
                    format: .json,
                    write: { output.append($0) }
                )
                exitedWithFailure = false
            } catch is ExitCode {
                exitedWithFailure = true
            }
            #expect(output.count == 1)
            let json = try #require(output.first)
            let decoded = try JSONDecoder().decode(
                TKTestReliabilitySampleResponse.self,
                from: Data(json.utf8)
            )
            #expect(exitedWithFailure)
            #expect(decoded == response)
            #expect(!decoded.ok)
            #expect(!json.contains("\"error\""))
        }
    }
}

private final class HarnessFakeExecutor: TKTestRunPrimitiveExecutor {
    private(set) var operations: [String] = []
    private(set) var plans: [TKTestNormalizedPlan] = []

    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        operations.append(step.type)
        if plans.isEmpty {
            plans.append(plan)
        }
        return .passed(command: ["fake", step.type])
    }
}

private final class HarnessReserveResults: @unchecked Sendable {
    private let lock = NSLock()
    private var successes: [TKTestReliabilityReserveResponse] = []
    private var harnessErrors: [TKTestReliabilityHarnessError] = []
    private var unexpectedErrorCount = 0

    func recordSuccess(_ response: TKTestReliabilityReserveResponse) {
        lock.withLock { successes.append(response) }
    }

    func recordHarnessError(_ error: TKTestReliabilityHarnessError) {
        lock.withLock { harnessErrors.append(error) }
    }

    func recordUnexpectedError() {
        lock.withLock { unexpectedErrorCount += 1 }
    }

    func snapshot() -> (
        successes: [TKTestReliabilityReserveResponse],
        harnessErrors: [TKTestReliabilityHarnessError],
        unexpectedErrorCount: Int
    ) {
        lock.withLock { (successes, harnessErrors, unexpectedErrorCount) }
    }
}

private final class HarnessFailingExecutor: TKTestRunPrimitiveExecutor {
    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        if step.type == "assertVisible" {
            return .failed(
                command: ["fake", step.type],
                failure: TKTestRunFailure(
                    type: "assert_visible_failed",
                    message: "Intentional fake reliability failure"
                )
            )
        }
        return .passed(command: ["fake", step.type])
    }
}

private final class HarnessTargetResolver: TKTestReliabilityRuntimeTargetResolver {
    private(set) var calls = 0
    private let summary: TKTargetSummary

    init(summary: TKTargetSummary) {
        self.summary = summary
    }

    func resolve(
        receiptTarget: TKTestReliabilityCollectionTarget,
        host: String,
        port: Int
    ) async throws -> TKTargetSummary {
        calls += 1
        return summary
    }
}

private func replaceJSONField(at url: URL, key: String, value: Any) throws {
    guard var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
        throw RuntimeError("Expected a JSON object")
    }
    object[key] = value
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url, options: .atomic)
}

private func replaceManifestArtifactPath(at url: URL, kind: String, path: String) throws {
    guard var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
          var artifacts = object["artifacts"] as? [[String: Any]],
          let index = artifacts.firstIndex(where: { $0["kind"] as? String == kind }) else {
        throw RuntimeError("Expected the reliability artifact in the manifest")
    }
    artifacts[index]["path"] = path
    object["artifacts"] = artifacts
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url, options: .atomic)
}

private func replaceReceiptFlowField(
    at url: URL,
    flowID: String,
    key: String,
    value: Any
) throws {
    guard var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
          var flows = object["flows"] as? [[String: Any]],
          let index = flows.firstIndex(where: { $0["flowID"] as? String == flowID }) else {
        throw RuntimeError("Expected the frozen receipt flow")
    }
    flows[index][key] = value
    object["flows"] = flows
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url, options: .atomic)
}

private final class ReliabilityHarnessFixture {
    let root: URL
    let evidenceRoot: URL
    let simulatorUDID = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
    let bundleID = "com.private.reliabilityharness"

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-reliability-harness-\(UUID().uuidString)", isDirectory: true)
        evidenceRoot = root.appendingPathComponent("private-evidence-root", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var targetID: String {
        TKIOSSimulatorRuntimeTargetID(simulatorUDID: simulatorUDID, bundleIdentifier: bundleID)
    }

    var targetBindingDigest: String {
        fnv1a64Hex(Data(targetID.utf8))
    }

    func targetResolver(bundleID: String? = nil) -> HarnessTargetResolver {
        let resolvedBundleID = bundleID ?? self.bundleID
        let resolvedTarget = TKIOSSimulatorRuntimeTargetID(
            simulatorUDID: simulatorUDID,
            bundleIdentifier: resolvedBundleID
        )
        return HarnessTargetResolver(
            summary: TKTargetSummary(
                id: resolvedTarget,
                transport: "ios-simulator",
                connected: true,
                latestHierarchyAvailable: true,
                bundleIdentifier: resolvedBundleID,
                simulatorUDID: simulatorUDID,
                platform: "ios"
            )
        )
    }

    func runtimeTargetSummary(
        id: String,
        bundleIdentifier: String?,
        connected: Bool = true,
        platform: String = "ios",
        simulatorUDID: String? = nil
    ) -> TKTargetSummary {
        TKTargetSummary(
            id: id,
            transport: "ios-simulator",
            connected: connected,
            latestHierarchyAvailable: connected,
            bundleIdentifier: bundleIdentifier,
            simulatorUDID: simulatorUDID ?? self.simulatorUDID,
            platform: platform
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func validCollection() -> TKTestReliabilityCollection {
        let alpha = try! plan(name: "alpha", visibleText: "Alpha screen")
        let beta = try! plan(name: "beta", visibleText: "Beta screen")
        let gamma = try! plan(name: "gamma", visibleText: "Gamma screen")
        let negative = try! plan(name: "negative", visibleText: "Negative screen")
        return TKTestReliabilityCollection(
            schemaVersion: 1,
            kind: "triton.test.reliability-collection",
            target: TKTestReliabilityCollectionTarget(
                id: targetID,
                simulatorUDID: simulatorUDID,
                bundleID: bundleID,
                bindingDigest: targetBindingDigest
            ),
            evidenceRoot: evidenceRoot.path,
            flows: [
                flow(id: "flow-alpha", plan: alpha, initialStateID: "initial-alpha", resetRecipeID: "reset-alpha"),
                flow(id: "flow-beta", plan: beta, initialStateID: "initial-beta", resetRecipeID: "reset-beta"),
                flow(id: "flow-gamma", plan: gamma, initialStateID: "initial-gamma", resetRecipeID: "reset-gamma"),
            ],
            negativeControls: [
                TKTestReliabilityCollectionNegativeControl(
                    flowID: "negative-control",
                    plan: negative.url.path,
                    expectedPlanDigest: negative.digest,
                    initialStateID: "initial-negative",
                    resetRecipeID: "reset-negative",
                    slot: 1,
                    expectedOutcome: "nonpassed"
                ),
            ]
        )
    }

    func collection(
        _ base: TKTestReliabilityCollection,
        flows: [TKTestReliabilityCollectionFlow]? = nil
    ) -> TKTestReliabilityCollection {
        TKTestReliabilityCollection(
            schemaVersion: base.schemaVersion,
            kind: base.kind,
            target: base.target,
            evidenceRoot: base.evidenceRoot,
            flows: flows ?? base.flows,
            negativeControls: base.negativeControls
        )
    }

    func writeCollection(_ collection: TKTestReliabilityCollection) throws -> URL {
        let url = root.appendingPathComponent("collection-\(UUID().uuidString).json")
        try prettyEncodedData(collection).write(to: url, options: .atomic)
        return url
    }

    func plan(name: String, visibleText: String) throws -> (url: URL, digest: String) {
        let url = root.appendingPathComponent("\(name)-\(UUID().uuidString).tritontest.yaml")
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
              source: ax
              match: exact
        """
        try yaml.write(to: url, atomically: true, encoding: .utf8)
        let normalized = try validateTritonTestContract(yaml: yaml, inputPath: url.path)
        return (url, fnv1a64Hex(try prettyEncodedData(normalized)))
    }

    func planWithoutLaunch(name: String, visibleText: String) throws -> (url: URL, digest: String) {
        let url = root.appendingPathComponent("\(name)-\(UUID().uuidString).tritontest.yaml")
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
          - takeScreenshot: {}
          - assertVisible:
              text: \(visibleText)
              source: ax
              match: exact
        """
        try yaml.write(to: url, atomically: true, encoding: .utf8)
        let normalized = try validateTritonTestContract(yaml: yaml, inputPath: url.path)
        return (url, fnv1a64Hex(try prettyEncodedData(normalized)))
    }

    func writeResetReceipt(
        receiptURL: URL,
        flowID: String,
        slot: Int,
        verified: Bool = true
    ) throws -> URL {
        let receiptData = try Data(contentsOf: receiptURL)
        let receipt = try JSONDecoder().decode(TKTestReliabilityCollectionReceipt.self, from: receiptData)
        let frozenFlow = try #require(receipt.flows.first { $0.flowID == flowID })
        let reset = TKTestReliabilityResetReceipt(
            collectionReceiptDigest: fnv1a64Hex(receiptData),
            flowID: frozenFlow.flowID,
            slot: slot,
            targetBindingDigest: receipt.target.bindingDigest,
            initialStateID: frozenFlow.initialStateID,
            resetRecipeID: frozenFlow.resetRecipeID,
            resetEvidenceID: "reset-evidence-\(flowID)-\(slot)",
            verified: verified
        )
        let url = root.appendingPathComponent("reset-\(UUID().uuidString).json")
        try prettyEncodedData(reset).write(to: url, options: .atomic)
        return url
    }

    func rewritePlan(at url: URL, name: String, visibleText: String) throws {
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
              source: ax
              match: exact
        """
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func flow(
        id: String,
        plan: (url: URL, digest: String),
        initialStateID: String,
        resetRecipeID: String
    ) -> TKTestReliabilityCollectionFlow {
        TKTestReliabilityCollectionFlow(
            flowID: id,
            plan: plan.url.path,
            expectedPlanDigest: plan.digest,
            initialStateID: initialStateID,
            resetRecipeID: resetRecipeID,
            slots: Array(1...20)
        )
    }
}
