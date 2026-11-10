import Foundation
import Testing
@testable import TritonKitShared

@Suite("ActionContext and ActionAdmission P0 contract")
struct TKActionContextModelsTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("canonical argument digest is stable across object key order")
    func canonicalArgumentsDigestIsStable() throws {
        let left: [String: TKJSONValue] = [
            "z": .int(1),
            "nested": .object(["b": .string("two"), "a": .bool(true)])
        ]
        let right: [String: TKJSONValue] = [
            "nested": .object(["a": .bool(true), "b": .string("two")]),
            "z": .int(1)
        ]

        let first = try TKActionArgumentsDigest.make(arguments: left)
        let second = try TKActionArgumentsDigest.make(arguments: right)

        #expect(first == second)
        #expect(first.algorithm == .sha256)
        #expect(first.digest.count == 64)
        #expect(first.canonicalizationVersion == TKActionArgumentsDigest.currentCanonicalizationVersion)
    }

    @Test("HMAC digest requires a key and differs from public SHA digest")
    func hmacDigestRequiresKey() throws {
        let arguments: [String: TKJSONValue] = ["text": .string("sensitive")]
        let sha = try TKActionArgumentsDigest.make(arguments: arguments)
        let hmac = try TKActionArgumentsDigest.make(
            arguments: arguments,
            algorithm: .hmacSHA256,
            key: Data(repeating: 7, count: 32),
            redactionProfile: "credentials"
        )

        #expect(sha.digest != hmac.digest)
        #expect(hmac.algorithm == .hmacSHA256)
        #expect(hmac.redactionProfile == "credentials")

        do {
            _ = try TKActionArgumentsDigest.make(arguments: arguments, algorithm: .hmacSHA256)
            Issue.record("HMAC digest without key unexpectedly succeeded")
        } catch let error as TKActionArgumentsDigestError {
            #expect(error == .hmacKeyRequired)
        }
    }

    @Test("action context round trips and validates required identity")
    func actionContextRoundTrip() throws {
        let args = try TKActionArgumentsDigest.make(arguments: ["x": .int(12)])
        let context = TKActionContext(
            actionID: "action-1",
            runID: "run-1",
            stepID: "step-1",
            sessionID: "session-1",
            target: "sim:target-1",
            operation: "sim.tap",
            argsDigest: args.digest,
            argsDigestAlgorithm: args.algorithm,
            argsCanonicalizationVersion: args.canonicalizationVersion,
            argsRedactionProfile: args.redactionProfile,
            leaseID: "lease-1",
            leaseOwner: "agent-1",
            observationID: "obs-1",
            observationRevision: "rev-1",
            runtimeInstanceID: "runtime-1",
            coordinateSpace: "simulator-points",
            policyDecision: .allow,
            admissionID: nil,
            createdAt: "2026-11-10T13:00:00Z"
        )

        try context.validate()
        #expect(try context.contextDigest().count == 64)
        let decoded = try JSONDecoder().decode(TKActionContext.self, from: JSONEncoder().encode(context))
        #expect(decoded == context)

        do {
            var invalid = context
            invalid.actionID = ""
            try invalid.validate()
            Issue.record("Invalid action context unexpectedly validated")
        } catch let error as TKActionContextValidationError {
            #expect(error == .actionIDRequired)
        }

        do {
            var invalid = context
            invalid.schemaVersion = 99
            try invalid.validate()
            Issue.record("Unsupported action context schema unexpectedly validated")
        } catch let error as TKActionContextValidationError {
            #expect(error == .unsupportedSchemaVersion)
        }
    }

    @Test("admission binds context digest, target and lease")
    func admissionBindsIdentity() throws {
        let store = TKActionAdmissionStore()
        let issued = try store.issue(
            actionID: "action-1",
            contextDigest: "ctx-1",
            target: "target-1",
            leaseID: "lease-1",
            now: fixedNow,
            ttlSeconds: 30
        )

        let consumed = try store.consume(
            admissionID: issued.admissionID,
            contextDigest: "ctx-1",
            target: "target-1",
            leaseID: "lease-1",
            now: fixedNow.addingTimeInterval(1)
        )
        #expect(consumed.state == .consumed)
        #expect(consumed.actionID == "action-1")
        let decoded = try JSONDecoder().decode(TKActionAdmission.self, from: JSONEncoder().encode(consumed))
        #expect(decoded == consumed)

        do {
            _ = try store.consume(
                admissionID: issued.admissionID,
                contextDigest: "ctx-1",
                target: "target-1",
                leaseID: "lease-1",
                now: fixedNow.addingTimeInterval(2)
            )
            Issue.record("Consumed admission was accepted twice")
        } catch let error as TKActionAdmissionError {
            #expect(error == .alreadyConsumed)
        }
    }

    @Test("duplicate admission IDs cannot overwrite an active admission")
    func duplicateAdmissionIDDoesNotOverwrite() throws {
        let store = TKActionAdmissionStore()
        _ = try store.issue(
            actionID: "action-original",
            contextDigest: "ctx-original",
            target: "target-original",
            leaseID: nil,
            now: fixedNow,
            ttlSeconds: 30,
            admissionID: "admission-fixed"
        )

        do {
            _ = try store.issue(
                actionID: "action-replacement",
                contextDigest: "ctx-replacement",
                target: "target-replacement",
                leaseID: nil,
                now: fixedNow,
                ttlSeconds: 30,
                admissionID: "admission-fixed"
            )
            Issue.record("Duplicate admission ID unexpectedly replaced the original")
        } catch let error as TKActionAdmissionError {
            #expect(error == .duplicateAdmissionID)
        }

        let original = try store.consume(
            admissionID: "admission-fixed",
            contextDigest: "ctx-original",
            target: "target-original",
            leaseID: nil,
            now: fixedNow.addingTimeInterval(1)
        )
        #expect(original.actionID == "action-original")
    }

    @Test("admission mismatch and expiry fail closed")
    func admissionMismatchAndExpiry() throws {
        let store = TKActionAdmissionStore()
        let issued = try store.issue(
            actionID: "action-2",
            contextDigest: "ctx-2",
            target: "target-2",
            leaseID: nil,
            now: fixedNow,
            ttlSeconds: 5
        )

        do {
            _ = try store.consume(
                admissionID: issued.admissionID,
                contextDigest: "ctx-other",
                target: "target-2",
                leaseID: nil,
                now: fixedNow.addingTimeInterval(1)
            )
            Issue.record("Mismatched context was accepted")
        } catch let error as TKActionAdmissionError {
            #expect(error == .bindingMismatch)
        }

        do {
            _ = try store.consume(
                admissionID: issued.admissionID,
                contextDigest: "ctx-2",
                target: "target-2",
                leaseID: nil,
                now: fixedNow.addingTimeInterval(6)
            )
            Issue.record("Expired admission was accepted")
        } catch let error as TKActionAdmissionError {
            #expect(error == .expired)
        }
    }

    @Test("cancelled admission cannot be consumed")
    func cancelledAdmission() throws {
        let store = TKActionAdmissionStore()
        let issued = try store.issue(
            actionID: "action-3",
            contextDigest: "ctx-3",
            target: "target-3",
            leaseID: "lease-3",
            now: fixedNow,
            ttlSeconds: 30
        )
        let cancelled = try store.cancel(admissionID: issued.admissionID, now: fixedNow.addingTimeInterval(1), reason: "stopped")
        #expect(cancelled.state == .cancelled)
        #expect(cancelled.cancelReason == "stopped")

        do {
            _ = try store.consume(
                admissionID: issued.admissionID,
                contextDigest: "ctx-3",
                target: "target-3",
                leaseID: "lease-3",
                now: fixedNow.addingTimeInterval(2)
            )
            Issue.record("Cancelled admission was accepted")
        } catch let error as TKActionAdmissionError {
            #expect(error == .cancelled)
        }
    }

    @Test("late results from older action generations are rejected")
    func lateResultsCannotCompleteNewGeneration() {
        let store = TKActionGenerationStore()
        let first = store.begin(target: "sim:target-generation", actionID: "action-1")
        #expect(store.isCurrent(first))

        let second = store.begin(target: "target-generation", actionID: "action-2")
        #expect(!store.isCurrent(first))
        #expect(store.isCurrent(second))
        #expect(second.generation == first.generation + 1)

        _ = store.invalidate(target: "sim:target-generation")
        #expect(!store.isCurrent(second))
    }

    @Test("concurrent target generations do not cross-contaminate")
    func concurrentTargetGenerationsRemainIsolated() {
        let store = TKActionGenerationStore()
        let group = DispatchGroup()
        let lock = NSLock()
        var tokens: [TKActionGenerationToken] = []
        for index in 0..<16 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                let token = store.begin(target: index.isMultiple(of: 2) ? "sim:target-a" : "sim:target-b", actionID: "action-\(index)")
                lock.withLock { tokens.append(token) }
            }
        }
        group.wait()
        #expect(tokens.count == 16)
        let currentA = tokens.filter { $0.target == "target-a" }.max { $0.generation < $1.generation }
        let currentB = tokens.filter { $0.target == "target-b" }.max { $0.generation < $1.generation }
        #expect(currentA.map(store.isCurrent) == true)
        #expect(currentB.map(store.isCurrent) == true)
        #expect(tokens.filter { $0.target == "target-a" }.filter(store.isCurrent).count == 1)
        #expect(tokens.filter { $0.target == "target-b" }.filter(store.isCurrent).count == 1)
    }

    @Test("concurrent consume accepts exactly one caller")
    func concurrentConsumeIsSingleUse() throws {
        let store = TKActionAdmissionStore()
        let issued = try store.issue(
            actionID: "action-concurrent",
            contextDigest: "ctx-concurrent",
            target: "target-concurrent",
            leaseID: nil,
            now: fixedNow,
            ttlSeconds: 30
        )
        let group = DispatchGroup()
        let lock = NSLock()
        var successes = 0

        for _ in 0..<32 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                do {
                    _ = try store.consume(
                        admissionID: issued.admissionID,
                        contextDigest: "ctx-concurrent",
                        target: "target-concurrent",
                        leaseID: nil,
                        now: fixedNow.addingTimeInterval(1)
                    )
                    lock.withLock { successes += 1 }
                } catch {
                    // Every loser is expected to see the one-time-use guard.
                }
            }
        }
        group.wait()
        #expect(successes == 1)
    }
}
