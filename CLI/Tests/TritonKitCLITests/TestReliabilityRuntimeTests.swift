import Foundation
import Testing
@testable import TritonKitCLI
import TritonKitShared

@Suite("SP-134 test reliability report")
struct TestReliabilityRuntimeTests {
    @Test("report groups repeatable supported samples without exposing private input")
    func reportGroupsRepeatableSamplesWithoutExposingPrivateInput() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let first = try fixture.writeEvidence(
            runID: "private-run-001",
            timestamp: "2026-07-27T00:00:00Z"
        )
        let second = try fixture.writeEvidence(
            runID: "private-run-002",
            timestamp: "2026-07-27T00:01:00Z"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: first),
            fixture.sample(flowID: "fixture-login-home", evidence: second),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 2,
                minimumFailureSamples: 0
            )
        )

        #expect(report.ok)
        #expect(report.kind == "triton.test.reliability-report")
        #expect(report.thresholds.minimumRunsPerFlow == 2)
        #expect(report.evidenceCompleteness.rate == 1)
        #expect(report.outcomeRepeatability.rate == 1)
        #expect(report.failureExplainability.state == .notEvaluable)
        #expect(report.identityChain == .notApplicable)
        #expect(report.stage1 == nil)
        #expect(report.flows.count == 1)
        #expect(report.flows[0].flowID.hasPrefix("flow_"))
        #expect(!report.flows[0].flowID.contains("fixture-login-home"))
        #expect(report.flows[0].sampleCount == 2)
        #expect(report.flows[0].planDigest.count == 16)

        let encoded = try encodeJSON(report)
        let encodedObject = try #require(
            JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any]
        )
        #expect(encodedObject["stage1"] == nil)
        #expect(!encoded.contains(fixture.root.path))
        #expect(!encoded.contains("com.private.fixture"))
        #expect(!encoded.contains("Sensitive Fixture Login"))
        #expect(!encoded.contains("private-run-001"))
        #expect(!encoded.contains("dedicated-target-secret"))
        #expect(!encoded.contains("fixture-login-home"))
    }

    @Test("legacy samples remain diagnostic and cannot pass the Stage 1 gate")
    func legacySamplesRemainDiagnosticAndCannotPassStage1Gate() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }

        let flows = [
            ("legacy-flow-a", "legacy-plan-a"),
            ("legacy-flow-b", "legacy-plan-b"),
            ("legacy-flow-c", "legacy-plan-c"),
        ]
        var samples: [TKTestReliabilitySample] = []
        for (flowID, planName) in flows {
            for index in 0..<20 {
                let evidence = try fixture.writeEvidence(
                    runID: "\(flowID)-\(index)",
                    planName: planName
                )
                samples.append(fixture.sample(flowID: flowID, evidence: evidence))
            }
        }
        let negative = try fixture.writeEvidence(
            runID: "legacy-negative",
            planName: "legacy-negative-plan",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        samples.append(fixture.sample(
            flowID: "legacy-negative-control",
            evidence: negative,
            classification: .negativeControl
        ))

        let report = try buildTritonTestReliabilityReport(samples: samples)

        #expect(report.evidenceCompleteness.rate == 1)
        #expect(report.failureExplainability.rate == 1)
        #expect(report.outcomeRepeatability.rate == 1)
        #expect(report.gateAuthority == .legacyDiagnostic)
        #expect(!report.eligibleForStage1Gate)
        #expect(report.stage1 == nil)
        #expect(report.gate.status == .blocked)
        #expect(report.gate.blockerCodes.contains("receipt_required"))
    }

    @Test("reliability rejects an observation that points screenshot at a declared artifact of the wrong kind")
    func reliabilityRejectsObservationArtifactKindMismatch() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = try fixture.writeEvidence(
            runID: "observation-kind-mismatch",
            observationScreenshotRef: "normalized-plan.json"
        )

        let report = try buildTritonTestReliabilityReport(
            samples: [fixture.sample(flowID: "fixture-login-home", evidence: evidence)],
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["observation_artifact_kind_mismatch"] == 1)
    }

    @Test("reliability rejects an observation that borrows artifacts created for an earlier step")
    func reliabilityRejectsObservationArtifactFromEarlierStep() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = try fixture.writeEvidence(
            runID: "observation-artifact-step-mismatch",
            observationArtifactCreationStepIndex: 0
        )

        let report = try buildTritonTestReliabilityReport(
            samples: [fixture.sample(flowID: "fixture-login-home", evidence: evidence)],
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["observation_artifact_step_mismatch"] == 1)
    }

    @Test("reliability rejects an observation whose artifact predates that step command")
    func reliabilityRejectsObservationArtifactBeforeStepCommand() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = try fixture.writeEvidence(
            runID: "observation-artifact-before-command",
            observationArtifactsBeforeCommand: true
        )

        let report = try buildTritonTestReliabilityReport(
            samples: [fixture.sample(flowID: "fixture-login-home", evidence: evidence)],
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["observation_artifact_step_mismatch"] == 1)
    }

    @Test("reliability rejects a terminal failure that borrows an artifact from an earlier step")
    func reliabilityRejectsTerminalFailureArtifactFromEarlierStep() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = try fixture.writeEvidence(
            runID: "failure-artifact-step-mismatch",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["runtime-target.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )

        let report = try buildTritonTestReliabilityReport(
            samples: [fixture.sample(
                flowID: "fixture-negative-control",
                evidence: evidence,
                classification: .negativeControl
            )],
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 0,
                minimumRunsPerFlow: 0,
                minimumFailureSamples: 1
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.failureExplainability.numerator == 0)
        #expect(report.issueCounts["terminal_failure_artifact_step_mismatch"] == 1)
    }

    @Test("report marks missing evidence and unexplained failures as incomplete")
    func reportMarksMissingEvidenceAndUnexplainedFailuresAsIncomplete() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let completeFailure = try fixture.writeEvidence(
            runID: "failure-known",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        let unknownFailure = try fixture.writeEvidence(
            runID: "failure-unknown",
            status: .failed,
            failureType: "future_private_failure",
            failureArtifactRefs: []
        )
        let missingTarget = try fixture.writeEvidence(
            runID: "missing-target",
            includeRuntimeTarget: false
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-negative-control", evidence: completeFailure, classification: .negativeControl),
            fixture.sample(flowID: "fixture-negative-control", evidence: unknownFailure, classification: .negativeControl),
            fixture.sample(flowID: "fixture-login-home", evidence: missingTarget),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 1
            )
        )

        #expect(report.evidenceCompleteness.numerator == 1)
        #expect(report.evidenceCompleteness.denominator == 3)
        #expect(report.failureExplainability.state == .measured)
        #expect(report.failureExplainability.numerator == 1)
        #expect(report.failureExplainability.denominator == 2)
        #expect(report.failureExplainability.rate == 0.5)
        #expect(report.issueCounts["missing_runtime_target"] == 1)
        #expect(report.issueCounts["missing_failure_recovery"] == 1)
        #expect(report.issueCounts["missing_failure_artifact_ref"] == 1)
        #expect(report.gate.status == .blocked)
    }

    @Test("gate requires declared supported flows, runs, and a measurable failure sample")
    func gateRequiresDeclaredSupportedFlowsRunsAndMeasurableFailureSample() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let flowA = try fixture.writeEvidence(runID: "a-1")
        let flowB = try fixture.writeEvidence(runID: "b-1", planName: "fixture-settings")
        let flowC = try fixture.writeEvidence(runID: "c-1", planName: "fixture-delayed")
        let negative = try fixture.writeEvidence(
            runID: "negative-1",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: flowA),
            fixture.sample(flowID: "fixture-settings", evidence: flowB),
            fixture.sample(flowID: "fixture-delayed", evidence: flowC),
            fixture.sample(flowID: "fixture-negative-control", evidence: negative, classification: .negativeControl),
        ])

        let relaxed = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 3,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 1
            )
        )
        #expect(relaxed.gateAuthority == .legacyDiagnostic)
        #expect(!relaxed.eligibleForStage1Gate)
        #expect(relaxed.gate.status == .blocked)
        #expect(relaxed.gate.blockerCodes.contains("receipt_required"))

        let canonical = try buildTritonTestReliabilityReport(samplesPath: sampleSet.path)
        #expect(canonical.gate.status == .blocked)
        #expect(canonical.gate.blockerCodes.contains("insufficient_supported_runs"))
    }

    @Test("a repeated evidence bundle cannot fabricate the canonical reliability sample count")
    func repeatedEvidenceBundleCannotFabricateCanonicalSampleCount() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = [
            ("fixture-login-home", try fixture.writeEvidence(runID: "repeat-a")),
            ("fixture-settings", try fixture.writeEvidence(runID: "repeat-b", planName: "fixture-settings")),
            ("fixture-delayed", try fixture.writeEvidence(runID: "repeat-c", planName: "fixture-delayed")),
        ]
        let negative = try fixture.writeEvidence(
            runID: "repeat-negative",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        var samples: [TKTestReliabilitySample] = []
        for (flowID, bundle) in evidence {
            for _ in 0..<20 {
                samples.append(fixture.sample(flowID: flowID, evidence: bundle))
            }
        }
        samples.append(fixture.sample(
            flowID: "fixture-negative-control",
            evidence: negative,
            classification: .negativeControl
        ))
        let sampleSet = try fixture.writeSampleSet(samples)

        let report = try buildTritonTestReliabilityReport(samplesPath: sampleSet.path)

        #expect(report.evidenceCompleteness.numerator == 1)
        #expect(report.evidenceCompleteness.denominator == 61)
        #expect(report.issueCounts["duplicate_evidence_bundle"] == 60)
        #expect(report.issueCounts["duplicate_reset_evidence_id"] == 60)
        #expect(report.issueCounts["duplicate_run_id"] == 60)
        #expect(report.gate.status == .blocked)
        #expect(report.gate.blockerCodes.contains("evidence_completeness_below_threshold"))
    }

    @Test("an incomplete negative control cannot satisfy the canonical failure-sample threshold")
    func incompleteNegativeControlCannotSatisfyCanonicalFailureThreshold() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let flows = [
            ("fixture-login-home", "fixture-login-home"),
            ("fixture-settings", "fixture-settings"),
            ("fixture-delayed", "fixture-delayed"),
        ]
        var samples: [TKTestReliabilitySample] = []
        for (flowID, planName) in flows {
            for index in 0..<20 {
                let evidence = try fixture.writeEvidence(
                    runID: "\(flowID)-\(index)",
                    planName: planName
                )
                samples.append(fixture.sample(flowID: flowID, evidence: evidence))
            }
        }
        let partialFailure = try fixture.writeEvidence(
            runID: "partial-negative-control",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            partial: true,
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        samples.append(fixture.sample(
            flowID: "fixture-negative-control",
            evidence: partialFailure,
            classification: .negativeControl
        ))
        let sampleSet = try fixture.writeSampleSet(samples)

        let report = try buildTritonTestReliabilityReport(samplesPath: sampleSet.path)

        #expect(report.evidenceCompleteness.rate > 0.95)
        #expect(report.outcomeRepeatability.rate == 1)
        #expect(report.failureExplainability.state == .measured)
        #expect(report.failureExplainability.numerator == 0)
        #expect(report.failureExplainability.denominator == 1)
        #expect(report.failureExplainability.rate == 0)
        #expect(report.gate.status == .blocked)
        #expect(report.gate.blockerCodes.contains("failure_explainability_below_threshold"))
    }

    @Test("separate bundles cannot reuse a run identity or reset identity")
    func separateBundlesCannotReuseRunOrResetIdentity() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let sameRunFirst = try fixture.writeEvidence(runID: "copied-run")
        let sameRunSecond = try fixture.writeEvidence(runID: "copied-run")
        let sameResetFirst = try fixture.writeEvidence(runID: "reset-a")
        let sameResetSecond = try fixture.writeEvidence(runID: "reset-b")
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: sameRunFirst),
            fixture.sample(flowID: "fixture-login-home", evidence: sameRunSecond),
            fixture.sample(flowID: "fixture-login-home", evidence: sameResetFirst, resetEvidenceID: "shared-reset-evidence"),
            fixture.sample(flowID: "fixture-login-home", evidence: sameResetSecond, resetEvidenceID: "shared-reset-evidence"),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["duplicate_run_id"] == 2)
        #expect(report.issueCounts["duplicate_reset_evidence_id"] == 2)
    }

    @Test("repeatability detects initial state target and taxonomy drift while ignoring run identifiers")
    func repeatabilityDetectsSemanticDriftWhileIgnoringRunIdentifiers() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let stable = try fixture.writeEvidence(runID: "stable-run", timestamp: "2026-07-27T00:00:00Z")
        let drifted = try fixture.writeEvidence(
            runID: "drifted-run",
            timestamp: "2026-07-27T00:05:00Z",
            extraArtifactKind: "unexpected.taxonomy",
            runtimeTargetID: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: "different-simulator-udid",
                bundleIdentifier: "com.private.fixture"
            ),
            runtimeTargetSimulatorUDID: "different-simulator-udid"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: stable, initialStateID: "login-v1", targetToken: "dedicated-target-secret"),
            fixture.sample(flowID: "fixture-login-home", evidence: drifted, initialStateID: "login-v2", targetToken: "dedicated-target-secret"),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 2,
                minimumFailureSamples: 0
            )
        )

        #expect(report.outcomeRepeatability.rate == 0.5)
        #expect(report.issueCounts["initial_state_drift"] == 1)
        #expect(report.issueCounts["target_drift"] == 1)
        #expect(report.issueCounts["artifact_taxonomy_drift"] == 1)
    }

    @Test("reliability rejects a paused run instead of treating an interrupted sample as complete")
    func reliabilityRejectsPausedRun() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let paused = try fixture.writeEvidence(runID: "paused-run", status: .paused)
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: paused),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["non_terminal_run_status"] == 1)
    }

    @Test("partial evidence and a planless event log are not complete evidence")
    func partialEvidenceAndPlanlessEventLogAreNotCompleteEvidence() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let partial = try fixture.writeEvidence(runID: "partial-run", partial: true)
        let planless = try fixture.writeEvidence(runID: "planless-run", minimalEventLog: true)
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: partial),
            fixture.sample(flowID: "fixture-settings", evidence: planless),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["partial_evidence"] == 1)
        #expect(report.issueCounts["plan_step_coverage_mismatch"] == 1)
    }

    @Test("an interrupted or restarted run sequence cannot be treated as one completed sample")
    func interruptedOrRestartedRunSequenceCannotBeComplete() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let runID = "interrupted-run"
        let evidence = try fixture.writeEvidence(
            runID: runID,
            extraEventsBeforeFinish: [
                TKTestRunEvent(
                    type: .runPaused,
                    runID: runID,
                    timestamp: "2026-07-27T00:00:00Z",
                    status: .paused,
                    durationMs: 1,
                    phase: "operator"
                ),
                .runStarted(runID: runID, timestamp: "2026-07-27T00:00:01Z"),
            ]
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: evidence),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["invalid_run_sequence"] == 1)
    }

    @Test("runtime target and evidence target must bind before repeatability is measured")
    func runtimeTargetAndEvidenceTargetMustBind() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = try fixture.writeEvidence(
            runID: "target-mismatch",
            runtimeTargetID: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: "runtime-simulator-udid",
                bundleIdentifier: "com.private.fixture"
            ),
            manifestTargetID: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: "manifest-simulator-udid",
                bundleIdentifier: "com.private.fixture"
            ),
            runtimeTargetSimulatorUDID: "runtime-simulator-udid"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: evidence),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["runtime_manifest_target_mismatch"] == 1)
    }

    @Test("runtime target must identify an iOS Simulator and the normalized plan bundle")
    func runtimeTargetMustIdentifySimulatorAndPlanBundle() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let noSimulatorIdentity = try fixture.writeEvidence(
            runID: "missing-simulator-identity",
            runtimeTargetSimulatorUDID: nil
        )
        let wrongBundle = try fixture.writeEvidence(
            runID: "wrong-runtime-bundle",
            runtimeTargetID: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: "fixture-simulator-udid",
                bundleIdentifier: "com.private.other"
            ),
            runtimeTargetBundleID: "com.private.other"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: noSimulatorIdentity),
            fixture.sample(flowID: "fixture-settings", evidence: wrongBundle),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["invalid_ios_simulator_runtime_target"] == 1)
        #expect(report.issueCounts["runtime_plan_bundle_mismatch"] == 1)
    }

    @Test("reliability requires canonical connected Simulator identity and declared sidecars")
    func reliabilityRequiresCanonicalConnectedSimulatorIdentityAndDeclaredSidecars() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let forgedIdentity = try fixture.writeEvidence(
            runID: "forged-simulator-identity",
            runtimeTargetID: "triton:ios-simulator:other-simulator/app:com.private.fixture"
        )
        let disconnected = try fixture.writeEvidence(
            runID: "disconnected-simulator-target",
            runtimeTargetConnected: false,
            manifestTargetConnected: false
        )
        let missingSidecars = try fixture.writeEvidence(
            runID: "missing-declared-sidecars",
            includeNormalizedPlanArtifact: false,
            includeRuntimeTargetArtifact: false
        )
        let wrongArtifactTarget = try fixture.writeEvidence(
            runID: "wrong-runtime-artifact-target",
            runtimeTargetArtifactTargetID: "triton:ios-simulator:other-simulator/app:com.private.fixture"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: forgedIdentity),
            fixture.sample(flowID: "fixture-settings", evidence: disconnected),
            fixture.sample(flowID: "fixture-delayed", evidence: missingSidecars),
            fixture.sample(flowID: "fixture-profile", evidence: wrongArtifactTarget),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["runtime_target_simulator_mismatch"] == 1)
        #expect(report.issueCounts["disconnected_runtime_target"] == 1)
        #expect(report.issueCounts["disconnected_manifest_target"] == 1)
        #expect(report.issueCounts["missing_normalized_plan_artifact"] == 1)
        #expect(report.issueCounts["missing_runtime_target_artifact"] == 1)
        #expect(report.issueCounts["runtime_target_artifact_mismatch"] == 1)
    }

    @Test("reliability rejects blank bundle identities before target comparison")
    func reliabilityRejectsBlankBundleIdentities() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let blankBundles = try fixture.writeEvidence(
            runID: "blank-bundle-identities",
            runtimeTargetID: TKIOSSimulatorRuntimeTargetID(simulatorUDID: "fixture-simulator-udid"),
            planBundleID: "",
            runtimeTargetBundleID: "",
            manifestTargetBundleID: ""
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: blankBundles),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["missing_plan_bundle"] == 1)
        #expect(report.issueCounts["missing_runtime_target_bundle"] == 1)
        #expect(report.issueCounts["missing_manifest_target_bundle"] == 1)
        #expect(report.issueCounts["noncanonical_runtime_target_id"] == 1)
    }

    @Test("reliability requires declared event and observation counts")
    func reliabilityRequiresDeclaredEventAndObservationCounts() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let missingEventCount = try fixture.writeEvidence(
            runID: "missing-event-count",
            includeEventCount: false
        )
        let missingObservationCount = try fixture.writeEvidence(
            runID: "missing-observation-count",
            includeObservationCount: false
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: missingEventCount),
            fixture.sample(flowID: "fixture-settings", evidence: missingObservationCount),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["missing_run_event_count"] == 1)
        #expect(report.issueCounts["missing_run_observation_count"] == 1)
    }

    @Test("failure explanation must belong to the terminal failed step")
    func failureExplanationMustBelongToTerminalFailedStep() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let borrowedFailure = try fixture.writeEvidence(
            runID: "borrowed-failure",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            failureStepIndex: 0
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(
                flowID: "fixture-negative-control",
                evidence: borrowedFailure,
                classification: .negativeControl
            ),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 0,
                minimumRunsPerFlow: 0,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.failureExplainability.state == .measured)
        #expect(report.failureExplainability.numerator == 0)
        #expect(report.failureExplainability.denominator == 1)
        #expect(report.issueCounts["missing_terminal_failure_record"] == 1)
    }

    @Test("only contract-paired terminal failures are explainable")
    func onlyContractPairedTerminalFailuresAreExplainable() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let mismatchedAssertion = try fixture.writeEvidence(
            runID: "tap-assertion-mismatch",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "action",
            normalizedPlanStepType: "tap",
            eventStepType: "assertVisible"
        )
        let matchingAssertion = try fixture.writeEvidence(
            runID: "assertion-match",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        let mismatchedTap = try fixture.writeEvidence(
            runID: "assertion-tap-mismatch",
            status: .failed,
            failureType: "tap_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        let launchFailureOnTap = try fixture.writeEvidence(
            runID: "tap-launch-failure",
            status: .failed,
            failureType: "launch_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"]
        )
        let genericRunnerFailure = try fixture.writeEvidence(
            runID: "tap-generic-runner-failure",
            status: .failed,
            failureType: "primitive_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"]
        )
        let genericAssertionFailure = try fixture.writeEvidence(
            runID: "assertion-generic-runner-failure",
            status: .failed,
            failureType: "primitive_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        let unknownVLMFailure = try fixture.writeEvidence(
            runID: "tap-unknown-vlm-failure",
            status: .failed,
            failureType: "vlm_grounding_not_found",
            failureArtifactRefs: ["debug/step-001-ax.json"]
        )
        let mismatchedAIAssertion = try fixture.writeEvidence(
            runID: "extract-text-ai-assertion-mismatch",
            status: .failed,
            failureType: "ai_assertion_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "observation",
            normalizedPlanStepType: "extractTextWithAI"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-mismatch", evidence: mismatchedAssertion),
            fixture.sample(flowID: "fixture-assertion", evidence: matchingAssertion),
            fixture.sample(flowID: "fixture-tap-mismatch", evidence: mismatchedTap),
            fixture.sample(flowID: "fixture-launch", evidence: launchFailureOnTap),
            fixture.sample(flowID: "fixture-generic", evidence: genericRunnerFailure),
            fixture.sample(flowID: "fixture-generic-assertion", evidence: genericAssertionFailure),
            fixture.sample(flowID: "fixture-vlm", evidence: unknownVLMFailure),
            fixture.sample(flowID: "fixture-ai", evidence: mismatchedAIAssertion),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 0,
                minimumRunsPerFlow: 0,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 2)
        #expect(report.evidenceCompleteness.denominator == 8)
        #expect(report.failureExplainability.numerator == 2)
        #expect(report.failureExplainability.denominator == 8)
        #expect(report.issueCounts["terminal_failure_type_step_mismatch"] == 3)
        #expect(report.issueCounts["missing_failure_recovery"] == 3)
    }

    @Test("launch failure remains explainable for every canonical terminal step")
    func launchFailureRemainsExplainableForEveryCanonicalTerminalStep() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let terminalSteps = [
            (kind: "action", type: "launch"),
            (kind: "action", type: "stop"),
            (kind: "observation", type: "takeScreenshot"),
            (kind: "action", type: "tap"),
            (kind: "action", type: "input"),
            (kind: "action", type: "press"),
            (kind: "action", type: "swipe"),
            (kind: "assertion", type: "assertVisible"),
            (kind: "assertion", type: "assertNotVisible"),
            (kind: "action", type: "scrollUntilVisible"),
            (kind: "assertion", type: "assertWithAI"),
            (kind: "assertion", type: "assertNoDefectsWithAI"),
            (kind: "observation", type: "extractTextWithAI"),
            (kind: "assertion", type: "assertScreenshot"),
        ]
        let samples = try terminalSteps.enumerated().map { index, step in
            let evidence = try fixture.writeEvidence(
                runID: "launch-failure-\(index)",
                status: .failed,
                failureType: "launch_failed",
                failureArtifactRefs: ["debug/step-001-ax.json"],
                normalizedPlanStepKind: step.kind,
                normalizedPlanStepType: step.type
            )
            return fixture.sample(flowID: "fixture-launch-\(index)", evidence: evidence)
        }

        let report = try buildTritonTestReliabilityReport(
            samples: samples,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 0,
                minimumRunsPerFlow: 0,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == terminalSteps.count)
        #expect(report.evidenceCompleteness.denominator == terminalSteps.count)
        #expect(report.failureExplainability.numerator == terminalSteps.count)
        #expect(report.failureExplainability.denominator == terminalSteps.count)
        #expect(report.issueCounts["terminal_failure_type_step_mismatch"] == nil)
        #expect(report.issueCounts["missing_failure_recovery"] == nil)
    }

    @Test("reliability rejects a normalized plan with an unknown type or incompatible kind")
    func reliabilityRejectsSemanticPlanTampering() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let unknownStep = try fixture.writeEvidence(
            runID: "unknown-plan-step",
            normalizedPlanStepType: "untrustedStep",
            eventStepType: "untrustedStep"
        )
        let incompatibleKind = try fixture.writeEvidence(
            runID: "incompatible-plan-kind",
            normalizedPlanStepKind: "observation"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: unknownStep),
            fixture.sample(flowID: "fixture-settings", evidence: incompatibleKind),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["invalid_normalized_plan_steps"] == 2)
    }

    @Test("a passed terminal verdict cannot hide a failed nonoptional step")
    func passedTerminalCannotHideFailedNonoptionalStep() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let forgedPass = try fixture.writeEvidence(
            runID: "forged-passed-terminal",
            status: .failed,
            terminalStatus: .passed
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: forgedPass),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["plan_step_coverage_mismatch"] == 1)
    }

    @Test("a terminal failure cannot continue after an earlier nonoptional failure")
    func terminalFailureCannotContinueAfterEarlierNonoptionalFailure() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let impossibleFailure = try fixture.writeEvidence(
            runID: "continued-after-nonoptional-failure",
            status: .failed,
            firstStepStatus: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(
                flowID: "fixture-negative-control",
                evidence: impossibleFailure,
                classification: .negativeControl
            ),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 0,
                minimumRunsPerFlow: 0,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["plan_step_coverage_mismatch"] == 1)
    }

    @Test("an empty observation artifact object is rejected before action coverage")
    func emptyObservationArtifactObjectIsRejectedBeforeActionCoverage() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let emptyObservation = try fixture.writeEvidence(
            runID: "empty-observation-artifacts",
            emptyObservationArtifacts: true
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: emptyObservation),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["invalid_run_events"] == 1)
    }

    @Test("event observation and terminal failure refs must be declared by the evidence manifest")
    func eventObservationAndTerminalFailureRefsMustBeManifestDeclared() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let missingDeclarations = try fixture.writeEvidence(
            runID: "undeclared-event-artifacts",
            status: .failed,
            failureType: "assert_visible_failed",
            failureArtifactRefs: ["debug/step-001-ax.json"],
            includeObservationArtifactsInManifest: false,
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertVisible"
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(
                flowID: "fixture-negative-control",
                evidence: missingDeclarations,
                classification: .negativeControl
            ),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 0,
                minimumRunsPerFlow: 0,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.failureExplainability.state == .measured)
        #expect(report.failureExplainability.numerator == 0)
        #expect(report.failureExplainability.denominator == 1)
        #expect(report.issueCounts["undeclared_event_artifact"] == 1)
        #expect(report.issueCounts["undeclared_observation_artifact"] == 1)
        #expect(report.issueCounts["undeclared_failure_artifact_ref"] == 1)
    }

    @Test("known runner failures accept run-relative declared evidence refs")
    func knownRunnerFailuresAcceptRunRelativeDeclaredEvidenceRefs() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let screenshotBaselineMissing = try fixture.writeEvidence(
            runID: "screenshot-baseline-missing",
            status: .failed,
            failureType: "assert_screenshot_baseline_missing",
            failureArtifactRefs: ["../debug/step-001-ax.json"],
            useRunRelativeEventRefs: true,
            normalizedPlanStepKind: "assertion",
            normalizedPlanStepType: "assertScreenshot",
            eventStepType: "assertScreenshot"
        )
        let textNotFound = try fixture.writeEvidence(
            runID: "text-not-found",
            status: .failed,
            failureType: "text_not_found",
            failureArtifactRefs: ["../debug/step-001-ax.json"],
            useRunRelativeEventRefs: true
        )
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(
                flowID: "fixture-negative-screenshot",
                evidence: screenshotBaselineMissing,
                classification: .negativeControl
            ),
            fixture.sample(
                flowID: "fixture-negative-text",
                evidence: textNotFound,
                classification: .negativeControl
            ),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 0,
                minimumRunsPerFlow: 0,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 2)
        #expect(report.failureExplainability.state == .measured)
        #expect(report.failureExplainability.numerator == 2)
        #expect(report.failureExplainability.denominator == 2)
        #expect(report.issueCounts["missing_failure_recovery"] == nil)
        #expect(report.issueCounts["undeclared_event_artifact"] == nil)
        #expect(report.issueCounts["undeclared_observation_artifact"] == nil)
        #expect(report.issueCounts["undeclared_failure_artifact_ref"] == nil)
    }

    @Test("private flow keys such as run ids UUIDs and selectors are never echoed")
    func privateFlowKeysAreNeverEchoed() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let flowKeys = [
            "private-run-001",
            "123e4567-e89b-12d3-a456-426614174000",
            "login-submit",
            "flow-001",
        ]
        let sampleSet = try fixture.writeSampleSet([
            fixture.sample(flowID: flowKeys[0], evidence: try fixture.writeEvidence(runID: "opaque-a")),
            fixture.sample(flowID: flowKeys[1], evidence: try fixture.writeEvidence(runID: "opaque-b")),
            fixture.sample(flowID: flowKeys[2], evidence: try fixture.writeEvidence(runID: "opaque-c")),
            fixture.sample(flowID: flowKeys[3], evidence: try fixture.writeEvidence(runID: "opaque-d")),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 3,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )
        let encoded = try encodeJSON(report)

        #expect(report.flows.map(\.flowID) == ["flow_001", "flow_002", "flow_003", "flow_004"])
        for flowKey in flowKeys {
            #expect(!encoded.contains(flowKey))
        }
    }

    @Test("reliability marks missing reset identity as incomplete without rendering the private token")
    func reliabilityMarksMissingResetIdentityAsIncomplete() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = try fixture.writeEvidence(runID: "missing-reset")
        let sampleSet = try fixture.writeSampleSet([
            TKTestReliabilitySample(
                flowID: "fixture-login-home",
                evidence: evidence.path,
                initialStateID: "",
                resetEvidenceID: "",
                targetToken: ""
            ),
        ])

        let report = try buildTritonTestReliabilityReport(
            samplesPath: sampleSet.path,
            thresholds: TKTestReliabilityThresholds(
                minimumSupportedFlows: 1,
                minimumRunsPerFlow: 1,
                minimumFailureSamples: 0
            )
        )

        #expect(report.evidenceCompleteness.numerator == 0)
        #expect(report.issueCounts["missing_initial_state_id"] == 1)
        #expect(report.issueCounts["missing_reset_evidence_id"] == 1)
        #expect(report.issueCounts["missing_target_token"] == 1)
    }

    @Test("reliability parser and schema keep the gate offline and private")
    func reliabilityParserAndSchemaKeepGateOfflineAndPrivate() throws {
        let command = try TestReliability.parse([
            "--samples", "private-samples.json",
            "--json",
        ])
        let receiptCommand = try TestReliability.parse([
            "--collection-receipt", "private-root/collection-receipt.json",
            "--json",
        ])
        let reserve = try TestReliabilityReserve.parse([
            "--collection", "private-collection.json",
            "--json",
        ])
        let sample = try TestReliabilitySample.parse([
            "--collection-receipt", "private-root/collection-receipt.json",
            "--flow", "flow_001",
            "--slot", "1",
            "--reset-receipt", "private-reset.json",
            "--target", "triton:ios-simulator:00000000-0000-0000-0000-000000000000/app:com.example.private",
            "--confirm",
            "--json",
        ])
        #expect(command.samples == "private-samples.json")
        #expect(command.collectionReceipt == nil)
        #expect(command.json)
        #expect(receiptCommand.samples == nil)
        #expect(receiptCommand.collectionReceipt == "private-root/collection-receipt.json")
        #expect(reserve.collection == "private-collection.json")
        #expect(sample.flow == "flow_001")
        #expect(sample.slot == "1")
        #expect(sample.host == "127.0.0.1")
        #expect(sample.port == "19421")
        #expect(sample.confirm)

        let schema = try #require(commandSchemaMap()["test"])
        let subcommand = try #require(schema.subcommands.first { $0.name == "reliability" })
        let reserveSchema = try #require(schema.subcommands.first { $0.name == "reliability-reserve" })
        let sampleSchema = try #require(schema.subcommands.first { $0.name == "reliability-sample" })
        let contract = try #require(schema.outputContracts.first { $0.selector == "test.reliability" })
        let sampleContract = try #require(schema.outputContracts.first { $0.selector == "test.reliability-sample" })
        let flowID = try #require(contract.fields.first { $0.name == "flows[].flowID" })
        let identityChain = try #require(contract.fields.first { $0.name == "identityChain" })
        let stage1 = try #require(contract.fields.first { $0.name == "stage1" })
        let actualFailureType = try #require(sampleContract.fields.first { $0.name == "actualFailureType" })
        let chineseHelp = try #require(chineseCommandHelps()["test"])

        #expect(subcommand.requiredOptions == [])
        #expect(subcommand.oneOfRequiredOptions == [["--samples"], ["--collection-receipt"]])
        #expect(subcommand.outputSelectors == ["test.reliability"])
        #expect(reserveSchema.failureCodes.contains("reliability_reservation_exists"))
        #expect(sampleSchema.failureCodes.contains("reliability_sample_confirmation_required"))
        #expect(sampleSchema.failureCodes.contains("reliability_collection_busy"))
        #expect(sampleSchema.failureCodes.contains("reliability_identity_chain_write_failed"))
        #expect(sampleSchema.requiresServer)
        #expect(sampleSchema.requiresTarget)
        #expect(sampleSchema.requiresConfirmation)
        #expect(sampleSchema.sideEffect == "runtime-execution-private-evidence-write")
        #expect(sampleSchema.optionOverrides.first { $0.name == "--target" }?.type == "CanonicalRuntimeTarget")
        #expect(sampleSchema.optionOverrides.first { $0.name == "--target" }?.defaultValue == nil)
        #expect(sampleSchema.optionOverrides.first { $0.name == "--host" }?.defaultValue == "127.0.0.1")
        #expect(sampleSchema.optionOverrides.first { $0.name == "--port" }?.defaultValue == "19421")
        #expect(!schema.runtimeScope.contains("target required for reliability"))
        #expect(schema.runtimeScope.contains("already-running receipt-bound loopback server"))
        #expect(contract.fields.contains(where: { $0.name == "gate.blockerCodes" }))
        #expect(contract.fields.contains(where: { $0.name == "gateAuthority" }))
        #expect(contract.fields.contains(where: { $0.name == "eligibleForStage1Gate" }))
        #expect(contract.fields.contains(where: { $0.name == "identityChain.state" }))
        #expect(contract.fields.contains(where: { $0.name == "identityChain.receiptAnchorVerified" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.stage1A.expectedSupportedSlotCount" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.stage1A.completeSupportedSlotCount" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.stage1A.evidenceCompleteness" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.stage1A.outcomeRepeatability" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.stage1B.expectedReceiptControlSlotCount" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.stage1B.receiptControlIntegrity" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.stage1B.failureExplainability" }))
        #expect(contract.fields.contains(where: { $0.name == "stage1.gate.blockerCodes" }))
        #expect(sampleContract.fields.contains(where: {
            $0.name == "expectedFailureType" && !$0.required
        }))
        #expect(!actualFailureType.required)
        #expect(actualFailureType.description.contains("unexpected negative-control pass"))
        #expect(flowID.description.contains("opaque"))
        #expect(identityChain.description.lowercased().contains("private"))
        #expect(stage1.description.contains("60"))
        #expect(stage1.description.contains("61"))
        #expect(chineseHelp.options.contains(where: { $0.0 == "reliability --samples <private.json>" }))
        #expect(chineseHelp.options.contains(where: { $0.0 == "reliability --collection-receipt <private.json>" }))
        #expect(chineseHelp.options.contains(where: { $0.0.hasPrefix("reliability-sample --collection-receipt") }))
    }

    @Test("receipt-backed reliability failures recover only through non-mutating categories")
    func receiptBackedReliabilityRecoveryCategoriesAreNonMutating() {
        #expect(Set(TKCommandRecoveryCommand.recoveryCategories(
            forFailureCode: "reliability_reservation_exists"
        )) == Set(["diagnose"]))
        #expect(Set(TKCommandRecoveryCommand.recoveryCategories(
            forFailureCode: "reliability_slot_already_claimed"
        )) == Set(["diagnose"]))
        #expect(Set(TKCommandRecoveryCommand.recoveryCategories(
            forFailureCode: "reliability_collection_busy"
        )) == Set(["diagnose"]))
        #expect(Set(TKCommandRecoveryCommand.recoveryCategories(
            forFailureCode: "test_reliability_sample_failed"
        )) == Set(["diagnose", "archive"]))
        #expect(Set(TKCommandRecoveryCommand.recoveryCategories(
            forFailureCode: "reliability_identity_chain_write_failed"
        )) == Set(["diagnose", "archive"]))
    }

    @Test("a blocked reliability gate is a typed result rather than an error envelope")
    func blockedReliabilityGateUsesTypedResultAndFailureExit() throws {
        let fixture = try ReliabilityEvidenceFixture()
        defer { fixture.cleanup() }
        let evidence = try fixture.writeEvidence(runID: "typed-gate")
        let samples = try fixture.writeSampleSet([
            fixture.sample(flowID: "fixture-login-home", evidence: evidence),
        ])

        let result = try runReliabilityTriton([
            "test", "reliability",
            "--samples", samples.path,
            "--json",
        ])

        #expect(result.exitCode == 1)
        #expect(result.stderr.isEmpty)
        let report = try JSONDecoder().decode(
            TKTestReliabilityReport.self,
            from: Data(result.stdout.utf8)
        )
        #expect(report.ok)
        #expect(report.gate.status == .blocked)
        #expect(!result.stdout.contains("\"error\""))
    }

    @Test("reliability subprocess fixes triton to the current test-bundle sibling")
    func reliabilitySubprocessTritonCandidateRejectsBuildDecoys() throws {
        let currentBundle = URL(fileURLWithPath: "/private/tmp/sp140/current/arm64-apple-macosx/debug/TritonKitCLIPackageTests.xctest")
        let currentTestExecutable = currentBundle
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("TritonKitCLIPackageTests", isDirectory: false)
        let candidate = try #require(reliabilityTritonExecutableCandidate(testBundleURL: currentBundle))
        let executableCandidate = try #require(reliabilityTritonExecutableCandidate(testBundleURL: currentTestExecutable))
        let parentDecoy = URL(fileURLWithPath: "/private/tmp/sp140/current/arm64-apple-macosx/triton")
        let staleScratchDecoy = URL(fileURLWithPath: "/private/tmp/sp140/stale/arm64-apple-macosx/debug/triton")

        #expect(candidate.path == "/private/tmp/sp140/current/arm64-apple-macosx/debug/triton")
        #expect(executableCandidate == candidate)
        #expect(candidate != parentDecoy)
        #expect(candidate != staleScratchDecoy)
        #expect(reliabilityTritonExecutableCandidate(testBundleURL: URL(fileURLWithPath: "/private/tmp/sp140/current/unknown-test-runner")) == nil)
    }
}

private struct ReliabilityCLIRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private func runReliabilityTriton(_ arguments: [String]) throws -> ReliabilityCLIRunResult {
    let process = Process()
    process.executableURL = try reliabilityTritonExecutableURL()
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    return ReliabilityCLIRunResult(
        exitCode: process.terminationStatus,
        stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
        stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func reliabilityTritonExecutableURL() throws -> URL {
    guard let testBundleURL = reliabilityTestBundleURL(),
          let candidate = reliabilityTritonExecutableCandidate(testBundleURL: testBundleURL),
          FileManager.default.isExecutableFile(atPath: candidate.path) else {
        throw NSError(
            domain: "TritonKitCLITests.TestReliabilityRuntimeTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing current SwiftPM triton executable for reliability CLI regression test"]
        )
    }
    return candidate
}

private func reliabilityTritonExecutableCandidate(testBundleURL: URL) -> URL? {
    let bundleURL: URL
    if testBundleURL.pathExtension == "xctest" {
        bundleURL = testBundleURL
    } else {
        let macOSDirectory = testBundleURL.deletingLastPathComponent()
        let contentsDirectory = macOSDirectory.deletingLastPathComponent()
        let possibleBundle = contentsDirectory.deletingLastPathComponent()
        guard macOSDirectory.lastPathComponent == "MacOS",
              contentsDirectory.lastPathComponent == "Contents",
              possibleBundle.pathExtension == "xctest" else {
            return nil
        }
        bundleURL = possibleBundle
    }
    return bundleURL
        .deletingLastPathComponent()
        .appendingPathComponent("triton", isDirectory: false)
}

private func reliabilityTestBundleURL() -> URL? {
    let arguments = CommandLine.arguments
    guard let flagIndex = arguments.firstIndex(of: "--test-bundle-path"),
          arguments.indices.contains(flagIndex + 1) else {
        return nil
    }
    return URL(fileURLWithPath: arguments[flagIndex + 1])
}

private struct ReliabilityEvidenceFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("triton-reliability-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func sample(
        flowID: String,
        evidence: URL,
        classification: TKTestReliabilitySampleClassification = .supported,
        initialStateID: String = "fixture-login-v1",
        resetEvidenceID: String? = nil,
        targetToken: String = "dedicated-target-secret"
    ) -> TKTestReliabilitySample {
        TKTestReliabilitySample(
            flowID: flowID,
            classification: classification,
            evidence: evidence.path,
            initialStateID: initialStateID,
            resetEvidenceID: resetEvidenceID ?? "reset-\(evidence.lastPathComponent)",
            targetToken: targetToken
        )
    }

    func writeSampleSet(_ samples: [TKTestReliabilitySample]) throws -> URL {
        let output = root.appendingPathComponent("private-samples-\(UUID().uuidString).json")
        try prettyEncodedData(TKTestReliabilitySampleSet(samples: samples)).write(to: output, options: .atomic)
        return output
    }

    func writeEvidence(
        runID: String,
        timestamp: String = "2026-07-27T00:00:00Z",
        planName: String = "fixture-login-home",
        status: TKTestRunStatus = .passed,
        terminalStatus: TKTestRunStatus? = nil,
        firstStepStatus: TKTestRunStatus = .passed,
        failureType: String? = nil,
        failureArtifactRefs: [String] = [],
        includeRuntimeTarget: Bool = true,
        extraArtifactKind: String? = nil,
        partial: Bool = false,
        minimalEventLog: Bool = false,
        runtimeTargetID: String = TKIOSSimulatorRuntimeTargetID(
            simulatorUDID: "fixture-simulator-udid",
            bundleIdentifier: "com.private.fixture"
        ),
        manifestTargetID: String? = nil,
        planBundleID: String = "com.private.fixture",
        runtimeTargetBundleID: String? = "com.private.fixture",
        manifestTargetBundleID: String? = "com.private.fixture",
        runtimeTargetPlatform: String = "ios",
        runtimeTargetSimulatorUDID: String? = "fixture-simulator-udid",
        runtimeTargetConnected: Bool = true,
        manifestTargetConnected: Bool = true,
        includeNormalizedPlanArtifact: Bool = true,
        includeRuntimeTargetArtifact: Bool = true,
        runtimeTargetArtifactTargetID: String? = nil,
        includeEventCount: Bool = true,
        includeObservationCount: Bool = true,
        emptyObservationArtifacts: Bool = false,
        observationScreenshotRef: String? = nil,
        observationAXRef: String? = nil,
        observationHierarchyRef: String? = nil,
        includeObservationArtifactsInManifest: Bool = true,
        useRunRelativeEventRefs: Bool = false,
        normalizedPlanStepKind: String = "action",
        normalizedPlanStepType: String = "tap",
        eventStepType: String? = nil,
        observationArtifactCreationStepIndex: Int = 1,
        observationArtifactsBeforeCommand: Bool = false,
        failureStepIndex: Int? = nil,
        extraEventsBeforeFinish: [TKTestRunEvent] = []
    ) throws -> URL {
        let evidence = root.appendingPathComponent("evidence-\(UUID().uuidString).tritonevidence", isDirectory: true)
        let runDirectory = evidence.appendingPathComponent("run", isDirectory: true)
        let debugDirectory = evidence.appendingPathComponent("debug", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: debugDirectory, withIntermediateDirectories: true)

        let plan = normalizedPlan(
            name: planName,
            bundleID: planBundleID,
            secondStepKind: normalizedPlanStepKind,
            secondStepType: normalizedPlanStepType
        )
        try prettyEncodedData(plan).write(to: evidence.appendingPathComponent("normalized-plan.json"), options: .atomic)
        if includeRuntimeTarget {
            let runtimeTarget = TKTargetSummary(
                id: runtimeTargetID,
                connected: runtimeTargetConnected,
                latestHierarchyAvailable: true,
                bundleIdentifier: runtimeTargetBundleID,
                simulatorUDID: runtimeTargetSimulatorUDID,
                platform: runtimeTargetPlatform
            )
            try prettyEncodedData(runtimeTarget).write(
                to: evidence.appendingPathComponent("runtime-target.json"),
                options: .atomic
            )
        }

        let eventReference: (String) -> String = { path in
            useRunRelativeEventRefs ? "../\(path)" : path
        }
        let observationArtifacts = emptyObservationArtifacts
            ? TKTestRunObservationArtifacts()
            : TKTestRunObservationArtifacts(
                screenshot: eventReference(observationScreenshotRef ?? "debug/step-001-before.png"),
                ax: eventReference(observationAXRef ?? "debug/step-001-ax.json"),
                hierarchy: eventReference(observationHierarchyRef ?? "debug/step-001-hierarchy.json")
            )
        let candidate = TKTestRunScreenCandidate(
            screenshotSha256: "1111",
            axTextHash: "2222",
            hierarchySha256: "3333",
            visibleTexts: ["Sensitive Fixture Login"]
        )
        let failure = failureType.map {
            TKTestRunFailure(type: $0, message: "Sensitive private failure", artifactRefs: failureArtifactRefs)
        }
        let effectiveTerminalStatus = terminalStatus ?? status
        let effectiveEventStepType = eventStepType ?? normalizedPlanStepType
        let recordedFailureStepIndex = failure.map { _ in failureStepIndex ?? 1 }
        var events: [TKTestRunEvent]
        if minimalEventLog {
            events = [
                .runStarted(runID: runID, timestamp: timestamp),
                .runFinished(runID: runID, status: effectiveTerminalStatus, durationMs: 2, timestamp: timestamp),
            ]
        } else {
            events = [
                .runStarted(runID: runID, timestamp: timestamp),
                .stepStarted(runID: runID, stepIndex: 0, stepID: "step-000", stepType: "launch", timestamp: timestamp),
                .commandExecuted(runID: runID, stepIndex: 0, command: ["triton", "list"], status: firstStepStatus, exitCode: firstStepStatus == .passed ? 0 : 1, durationMs: 1, timestamp: timestamp),
                .artifactCreated(runID: runID, stepIndex: 0, kind: "runtime.target", ref: eventReference("runtime-target.json"), timestamp: timestamp),
                .stepFinished(runID: runID, stepIndex: 0, stepID: "step-000", status: firstStepStatus, durationMs: 1, timestamp: timestamp),
            ]
            if recordedFailureStepIndex == 0, let failure {
                events.append(.failureRecorded(runID: runID, stepIndex: 0, failure: failure, timestamp: timestamp))
            }
            let observationArtifactEvents = [
                TKTestRunEvent.artifactCreated(runID: runID, stepIndex: observationArtifactCreationStepIndex, kind: "screenshot", ref: eventReference("debug/step-001-before.png"), timestamp: timestamp),
                TKTestRunEvent.artifactCreated(runID: runID, stepIndex: observationArtifactCreationStepIndex, kind: "accessibility", ref: eventReference("debug/step-001-ax.json"), timestamp: timestamp),
                TKTestRunEvent.artifactCreated(runID: runID, stepIndex: observationArtifactCreationStepIndex, kind: "hierarchy", ref: eventReference("debug/step-001-hierarchy.json"), timestamp: timestamp),
            ]
            events.append(.stepStarted(
                runID: runID,
                stepIndex: 1,
                stepID: "step-001",
                stepType: effectiveEventStepType,
                timestamp: timestamp
            ))
            if observationArtifactsBeforeCommand {
                events.append(contentsOf: observationArtifactEvents)
            }
            events.append(.commandExecuted(
                runID: runID,
                stepIndex: 1,
                command: ["triton", effectiveEventStepType],
                status: status,
                exitCode: status == .passed ? 0 : 1,
                durationMs: 1,
                timestamp: timestamp
            ))
            if !observationArtifactsBeforeCommand {
                events.append(contentsOf: observationArtifactEvents)
            }
            events.append(contentsOf: [
                .observationCaptured(runID: runID, stepIndex: 1, phase: "before", artifacts: observationArtifacts, screenCandidate: candidate, timestamp: timestamp),
            ])
            if status == .passed {
                events.append(.observationCaptured(runID: runID, stepIndex: 1, phase: "after", artifacts: observationArtifacts, screenCandidate: candidate, changed: true, timestamp: timestamp))
            }
            if recordedFailureStepIndex == 1, let failure {
                events.append(.failureRecorded(runID: runID, stepIndex: 1, failure: failure, timestamp: timestamp))
            }
            events.append(.stepFinished(runID: runID, stepIndex: 1, stepID: "step-001", status: status, durationMs: 1, timestamp: timestamp))
            events.append(contentsOf: extraEventsBeforeFinish)
            events.append(.runFinished(runID: runID, status: effectiveTerminalStatus, durationMs: 2, timestamp: timestamp))
        }
        let eventData = try events.map { try encodeCompactJSON($0) }.joined(separator: "\n") + "\n"
        try Data(eventData.utf8).write(to: runDirectory.appendingPathComponent("events.jsonl"), options: .atomic)

        let run = TKTestRunMetadata(
            runID: runID,
            source: "private-plan-path",
            status: effectiveTerminalStatus,
            startedAt: timestamp,
            endedAt: timestamp,
            durationMs: 2,
            planRef: "../normalized-plan.json"
        )
        try prettyEncodedData(run).write(to: runDirectory.appendingPathComponent("run.json"), options: .atomic)
        for path in ["debug/step-001-before.png", "debug/step-001-ax.json", "debug/step-001-hierarchy.json"] {
            try Data("fixture".utf8).write(to: evidence.appendingPathComponent(path), options: .atomic)
        }

        var artifacts = [
            TKEvidenceArtifact(kind: "test.normalized-plan", path: "normalized-plan.json"),
            TKEvidenceArtifact(kind: "test.run.events", path: "run/events.jsonl"),
            TKEvidenceArtifact(kind: "test.run.meta", path: "run/run.json"),
            TKEvidenceArtifact(
                kind: "runtime.target",
                path: "runtime-target.json",
                target: runtimeTargetArtifactTargetID ?? runtimeTargetID
            ),
            TKEvidenceArtifact(kind: "screenshot", path: "debug/step-001-before.png"),
            TKEvidenceArtifact(kind: "accessibility", path: "debug/step-001-ax.json"),
            TKEvidenceArtifact(kind: "hierarchy", path: "debug/step-001-hierarchy.json"),
        ]
        if !includeRuntimeTarget {
            artifacts.removeAll { $0.kind == "runtime.target" }
        }
        if !includeNormalizedPlanArtifact {
            artifacts.removeAll { $0.kind == "test.normalized-plan" }
        }
        if !includeRuntimeTargetArtifact {
            artifacts.removeAll { $0.kind == "runtime.target" }
        }
        if !includeObservationArtifactsInManifest {
            artifacts.removeAll {
                $0.path == "debug/step-001-before.png"
                    || $0.path == "debug/step-001-ax.json"
                    || $0.path == "debug/step-001-hierarchy.json"
            }
        }
        if let extraArtifactKind {
            let path = "debug/extra.json"
            try Data("fixture".utf8).write(to: evidence.appendingPathComponent(path), options: .atomic)
            artifacts.append(TKEvidenceArtifact(kind: extraArtifactKind, path: path))
        }
        let manifest = TKEvidenceManifest(
            ok: effectiveTerminalStatus == .passed,
            partial: partial,
            name: "private-evidence",
            createdAt: timestamp,
            output: evidence.path,
            artifacts: artifacts,
            target: TKEvidenceTarget(
                id: manifestTargetID ?? runtimeTargetID,
                connected: manifestTargetConnected,
                bundleIdentifier: manifestTargetBundleID,
                identityState: "verified"
            ),
            cli: TKEvidenceCLI(version: "test"),
            run: TKEvidenceRunManifest(
                eventsPath: "run/events.jsonl",
                metaPath: "run/run.json",
                eventCount: includeEventCount ? events.count : nil,
                observationCount: includeObservationCount ? events.filter { $0.type == .observationCaptured }.count : nil,
                status: .completed,
                summary: TKEvidenceRunSummary(
                    runID: runID,
                    verdict: effectiveTerminalStatus == .passed ? .success : .failure,
                    stepCount: events.compactMap(\.stepIndex).reduce(into: Set<Int>()) { $0.insert($1) }.count
                )
            )
        )
        try prettyEncodedData(manifest).write(to: evidence.appendingPathComponent("manifest.json"), options: .atomic)
        return evidence
    }

    private func normalizedPlan(
        name: String,
        bundleID: String = "com.private.fixture",
        secondStepKind: String = "action",
        secondStepType: String = "tap"
    ) -> TKTestNormalizedPlan {
        TKTestNormalizedPlan(
            name: name,
            app: TKTestPlanApp(bundleId: bundleID),
            device: TKTestPlanDevice(platform: "ios-simulator"),
            settings: TKTestPlanSettings(strict: true, timeoutMs: 10_000, retry: TKTestPlanRetry(count: 0, intervalMs: 0)),
            steps: [
                TKTestPlanStep(index: 0, id: "step-000", kind: "action", type: "launch", optional: false, timeoutMs: nil, point: nil, selector: nil),
                TKTestPlanStep(index: 1, id: "step-001", kind: secondStepKind, type: secondStepType, optional: false, timeoutMs: nil, point: nil, selector: TKTestPlanSelector(text: "Sensitive Fixture Login", match: "exact", source: "ax")),
            ]
        )
    }
}
