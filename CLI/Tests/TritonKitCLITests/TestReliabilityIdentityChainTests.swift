import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("SP-145 private reliability identity-chain v2")
struct TestReliabilityIdentityChainTests {
    @Test("identity-chain v2 hashes exact raw components and canonical body")
    func identityChainHashesRawComponentsAndCanonicalBody() throws {
        let descriptor = identityDescriptor()
        let artifacts = identityArtifacts()

        let chain = try buildTritonTestReliabilityIdentityChainV2(
            descriptor: descriptor,
            artifacts: artifacts
        )

        #expect(chain.schemaVersion == 2)
        #expect(chain.kind == "triton.test.reliability-identity-chain")
        #expect(chain.body.receiptSha256 == descriptor.receiptSha256)
        #expect(chain.body.legacyReceiptDigest == descriptor.legacyReceiptDigest)
        #expect(chain.body.flowID == descriptor.flowID)
        #expect(chain.body.slot == descriptor.slot)
        #expect(chain.body.terminalStatus == descriptor.terminalStatus)
        #expect(chain.body.outcomeMatched == descriptor.outcomeMatched)
        #expect(chain.body.artifactSha256.binding == reliabilityIdentityChainSHA256(artifacts.binding))
        #expect(chain.body.artifactSha256.resetReceipt == reliabilityIdentityChainSHA256(artifacts.resetReceipt))
        #expect(chain.body.artifactSha256.normalizedPlan == reliabilityIdentityChainSHA256(artifacts.normalizedPlan))
        #expect(chain.body.artifactSha256.runtimeTarget == reliabilityIdentityChainSHA256(artifacts.runtimeTarget))
        #expect(chain.body.artifactSha256.runMetadata == reliabilityIdentityChainSHA256(artifacts.runMetadata))
        #expect(chain.body.artifactSha256.runEvents == reliabilityIdentityChainSHA256(artifacts.runEvents))
        #expect(chain.bodySha256 == reliabilityIdentityChainSHA256(try prettyEncodedData(chain.body)))
    }

    @Test("identity-chain v2 distinguishes missing, manifest, body, and artifact drift")
    func identityChainValidationFailsClosedWithoutPrivateValues() throws {
        let descriptor = identityDescriptor()
        let artifacts = identityArtifacts()
        let chain = try buildTritonTestReliabilityIdentityChainV2(
            descriptor: descriptor,
            artifacts: artifacts
        )
        let chainData = try prettyEncodedData(chain)

        let verified = validateTritonTestReliabilityIdentityChainV2(
            chainData: chainData,
            descriptor: descriptor,
            artifacts: artifacts,
            manifestDeclared: true
        )
        #expect(verified.state == .verified)
        #expect(verified.issues.isEmpty)

        let missing = validateTritonTestReliabilityIdentityChainV2(
            chainData: nil,
            descriptor: descriptor,
            artifacts: artifacts,
            manifestDeclared: false
        )
        #expect(missing.state == .missing)
        #expect(missing.issues == ["identity_chain_missing"])

        var driftedArtifacts = artifacts
        driftedArtifacts.runEvents = Data("drifted-events".utf8)
        let artifactDrift = validateTritonTestReliabilityIdentityChainV2(
            chainData: chainData,
            descriptor: descriptor,
            artifacts: driftedArtifacts,
            manifestDeclared: true
        )
        #expect(artifactDrift.state == .invalid)
        #expect(artifactDrift.issues.contains("identity_chain_artifact_drift"))

        let invalidManifest = validateTritonTestReliabilityIdentityChainV2(
            chainData: chainData,
            descriptor: descriptor,
            artifacts: artifacts,
            manifestDeclared: false
        )
        #expect(invalidManifest.state == .invalid)
        #expect(invalidManifest.issues.contains("identity_chain_manifest_invalid"))

        let bodyHashDrift = TKTestReliabilityIdentityChainV2(
            body: chain.body,
            bodySha256: String(repeating: "0", count: 64)
        )
        let invalidBody = validateTritonTestReliabilityIdentityChainV2(
            chainData: try prettyEncodedData(bodyHashDrift),
            descriptor: descriptor,
            artifacts: artifacts,
            manifestDeclared: true
        )
        #expect(invalidBody.state == .invalid)
        #expect(invalidBody.issues.contains("identity_chain_body_hash_mismatch"))

        let unavailableTerminal = validateTritonTestReliabilityIdentityChainV2(
            chainData: chainData,
            descriptor: nil,
            artifacts: artifacts,
            manifestDeclared: true
        )
        #expect(unavailableTerminal.state == .invalid)
        #expect(unavailableTerminal.issues == ["identity_chain_terminal_unavailable"])

        let pausedDescriptor = identityDescriptor(terminalStatus: .paused)
        #expect(throws: TKTestReliabilityIdentityChainError.invalidTerminalStatus) {
            _ = try buildTritonTestReliabilityIdentityChainV2(
                descriptor: pausedDescriptor,
                artifacts: artifacts
            )
        }
        let pausedBody = TKTestReliabilityIdentityChainBody(
            receiptSha256: pausedDescriptor.receiptSha256,
            legacyReceiptDigest: pausedDescriptor.legacyReceiptDigest,
            flowID: pausedDescriptor.flowID,
            classification: pausedDescriptor.classification,
            expectedOutcome: pausedDescriptor.expectedOutcome,
            targetBindingDigest: pausedDescriptor.targetBindingDigest,
            planDigest: pausedDescriptor.planDigest,
            executionIdentityDigest: pausedDescriptor.executionIdentityDigest,
            slot: pausedDescriptor.slot,
            terminalStatus: pausedDescriptor.terminalStatus,
            outcomeMatched: pausedDescriptor.outcomeMatched,
            artifactSha256: artifacts.sha256
        )
        let pausedChain = try TKTestReliabilityIdentityChainV2(body: pausedBody)
        let pausedValidation = validateTritonTestReliabilityIdentityChainV2(
            chainData: try prettyEncodedData(pausedChain),
            descriptor: pausedDescriptor,
            artifacts: artifacts,
            manifestDeclared: true
        )
        #expect(pausedValidation.state == .invalid)
        #expect(pausedValidation.issues == ["identity_chain_terminal_unavailable"])
    }

    private func identityDescriptor(
        terminalStatus: TKTestRunStatus = .passed
    ) -> TKTestReliabilityIdentityChainBody {
        TKTestReliabilityIdentityChainBody(
            receiptSha256: String(repeating: "a", count: 64),
            legacyReceiptDigest: "0123456789abcdef",
            flowID: "flow_001",
            classification: .supported,
            expectedOutcome: "passed",
            targetBindingDigest: "fedcba9876543210",
            planDigest: "0011223344556677",
            executionIdentityDigest: "7766554433221100",
            slot: 1,
            terminalStatus: terminalStatus,
            outcomeMatched: terminalStatus == .passed,
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

    private func identityArtifacts() -> TKTestReliabilityIdentityChainArtifactData {
        TKTestReliabilityIdentityChainArtifactData(
            binding: Data("binding".utf8),
            resetReceipt: Data("reset".utf8),
            normalizedPlan: Data("plan".utf8),
            runtimeTarget: Data("target".utf8),
            runMetadata: Data("run".utf8),
            runEvents: Data("events".utf8)
        )
    }
}
