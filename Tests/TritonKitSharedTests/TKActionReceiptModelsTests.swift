import Foundation
import Testing
@testable import TritonKitShared

@Suite("shared action receipt and admission coordinator")
struct TKActionReceiptModelsTests {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func context(leaseID: String? = "lease-1") throws -> TKActionContext {
        let digest = try TKActionArgumentsDigest.make(arguments: ["x": .int(1)])
        return TKActionContext(
            actionID: "action-shared-1",
            target: "sim:target-shared",
            operation: "device.tap",
            argsDigest: digest.digest,
            argsDigestAlgorithm: digest.algorithm,
            argsCanonicalizationVersion: digest.canonicalizationVersion,
            argsRedactionProfile: digest.redactionProfile,
            leaseID: leaseID,
            policyDecision: .allow,
            createdAt: "2026-11-10T18:00:00Z"
        )
    }

    @Test("coordinator issues one shared handle and receipt")
    func coordinatorIssuesReceipt() throws {
        let coordinator = TKActionAdmissionCoordinator(now: { self.now })
        let handle = try coordinator.admit(context: context())
        let receipt = try coordinator.receipt(
            handle,
            delivery: .delivered,
            outcome: .settled,
            executed: true,
            originalStatus: "settled",
            terminalStatus: "settled",
            postcondition: .unverified,
            evidencePersistence: .written,
            evidenceRefs: ["run/action-receipt.json"]
        )
        #expect(receipt.actionID == handle.context.actionID)
        #expect(receipt.admissionID == handle.admission.admissionID)
        #expect(receipt.contextDigest == handle.contextDigest)
        #expect(receipt.leaseID == "lease-1")
        #expect(receipt.generation == handle.generation.generation)
        try receipt.validate()
    }

    @Test("coordinator rejects late receipt from stale generation")
    func coordinatorRejectsLateReceipt() throws {
        let generations = TKActionGenerationStore()
        let coordinator = TKActionAdmissionCoordinator(generations: generations, now: { self.now })
        let handle = try coordinator.admit(context: context())
        _ = generations.begin(target: handle.context.target, actionID: "new-action")
        do {
            _ = try coordinator.receipt(handle, delivery: .unknown, outcome: .uncertain, executed: nil)
            Issue.record("stale generation unexpectedly produced a receipt")
        } catch let error as TKActionAdmissionCoordinatorError {
            #expect(error == .staleGeneration)
        }
    }

    @Test("receipt validation preserves uncertain and not-started invariants")
    func receiptInvariants() throws {
        let uncertain = TKActionReceipt(actionID: "a", operation: "device.tap", target: "t", delivery: .unknown, outcome: .uncertain, executed: nil)
        try uncertain.validate()
        let notStarted = TKActionReceipt(actionID: "b", operation: "device.tap", target: "t", delivery: .notStarted, outcome: .blocked, executed: false)
        try notStarted.validate()
        let invalid = TKActionReceipt(actionID: "c", operation: "device.tap", target: "t", delivery: .notStarted, outcome: .blocked, executed: true)
        #expect(throws: TKActionReceiptValidationError.self) { try invalid.validate() }
    }

    @Test("coordinator preserves lease-free compatibility")
    func leaseFreeCompatibility() throws {
        let coordinator = TKActionAdmissionCoordinator(now: { self.now })
        let handle = try coordinator.admit(context: context(leaseID: nil))
        #expect(handle.context.leaseID == nil)
        #expect(try coordinator.receipt(handle, delivery: .delivered, outcome: .settled, executed: true).leaseID == nil)
    }
    @Test("rejected policy and invalid TTL preserve the current generation")
    func rejectedAdmissionDoesNotInvalidateCurrent() throws {
        let coordinator = TKActionAdmissionCoordinator(now: { self.now })
        let original = try coordinator.admit(context: context())
        for policy in [TKActionPolicyDecision.deny, .approvalRequired, .unsupported, .unavailable] {
            var candidate = try context()
            candidate.policyDecision = policy
            #expect(throws: Error.self) { _ = try coordinator.admit(context: candidate) }
            #expect(coordinator.isCurrent(original))
        }
        #expect(throws: Error.self) { _ = try coordinator.admit(context: context(), ttlSeconds: 0) }
        #expect(coordinator.isCurrent(original))
    }

    @Test("uncertain cannot claim execution or confirmed delivery")
    func uncertainMatrix() {
        for (delivery, executed) in [(TKActionDelivery.unknown, Optional(true)), (.delivered, nil)] {
            let receipt = TKActionReceipt(actionID: "a", operation: "tap", target: "t", delivery: delivery, outcome: .uncertain, executed: executed)
            #expect(throws: TKActionReceiptValidationError.self) { try receipt.validate() }
        }
    }

}
