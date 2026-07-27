import Foundation
import TritonKitShared

func testRecorderProposalsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.proposals",
        format: "json",
        kind: "testrec-proposals-inspect",
        model: "TKTestRecorderProposalsResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether compile proposals were read without validation errors"),
            ("schemaVersion", "Int?", false, "Proposals response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.proposals when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("proposalCount", "Int?", false, "Number of proposals read from compile-proposals.jsonl"),
            ("proposals", "[TKTestRecorderCompileProposal]?", false, "Compile proposals read without applying them"),
            ("proposals[].proposalKind", "String?", false, "Proposal family such as contract.redaction"),
            ("proposals[].findingCode", "String?", false, "Finding code that produced the proposal"),
            ("proposals[].sourcePath", "String?", false, "Source artifact path associated with the proposal"),
            ("proposals[].status", "String?", false, "Proposal status; proposed for P0"),
            ("proposals[].suggestedChange", "String?", false, "Human-readable suggested change"),
            ("suggestedCommands", "[String]?", false, "Current executable follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}

func testRecorderMatrixOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.matrix",
        format: "json",
        kind: "testrec-matrix",
        model: "TKTestRecorderMatrixResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether every matrix target completed its offline diagnostic without blockers; not a real test verdict"),
            ("schemaVersion", "Int?", false, "Matrix response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.matrix when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("executor", "String?", false, "Executor used for every target; null means dry-run matrix"),
            ("evidenceRoot", "String?", false, "Optional root directory used to write per-target evidence bundles"),
            ("status", "String?", false, "Compatibility diagnostic status: ready, passed, or blocked; never a real test verdict"),
            ("verdictBoundary", "TKTestRecorderReplayVerdictBoundary?", false, "Additive boundary for offline testrec diagnostics"),
            ("verdictBoundary.classification", "String?", false, "offline-diagnostic for testrec matrix output"),
            ("verdictBoundary.countsAsRealTestVerdict", "Bool?", false, "Always false: status must not be treated as a real test verdict"),
            ("verdictBoundary.eligibleForReliabilityGate", "Bool?", false, "Always false: offline diagnostics cannot enter the reliability gate"),
            ("verdictBoundary.migrationCommands", "[String]?", false, "Placeholder-only import, validate, and run commands for the supported triton test path"),
            ("targetCount", "Int?", false, "Number of matrix targets"),
            ("readyCount", "Int?", false, "Number of dry-run targets ready for replay"),
            ("passedCount", "Int?", false, "Compatibility count of local-simulated targets passed; never a real test pass count"),
            ("blockedCount", "Int?", false, "Number of blocked targets"),
            ("results", "[TKTestRecorderMatrixTargetResult]?", false, "Per-target replay plan or local-simulated diagnostic summary"),
            ("results[].target", "String?", false, "Original platform[:device] target selector"),
            ("results[].platform", "String?", false, "Target platform"),
            ("results[].device", "String?", false, "Optional target device selector"),
            ("results[].status", "String?", false, "Compatibility diagnostic status: ready, passed, or blocked; never a real test verdict"),
            ("results[].dryRun", "Bool?", false, "Whether this target only planned replay"),
            ("results[].plannedStepCount", "Int?", false, "Planned or simulated step count"),
            ("results[].evidenceDir", "String?", false, "Per-target evidence bundle directory when local-simulated matrix evidence was requested"),
            ("results[].blockers", "[TKTestRecorderReplayBlocker]?", false, "Per-target blockers"),
            ("results[].verdictBoundary", "TKTestRecorderReplayVerdictBoundary?", false, "Same offline diagnostic boundary exposed by this target result"),
            ("results[].verdictBoundary.classification", "String?", false, "offline-diagnostic for each matrix target"),
            ("results[].verdictBoundary.countsAsRealTestVerdict", "Bool?", false, "Always false for each matrix target"),
            ("results[].verdictBoundary.eligibleForReliabilityGate", "Bool?", false, "Always false for each matrix target"),
            ("results[].verdictBoundary.migrationCommands", "[String]?", false, "Placeholder-only supported migration sequence"),
            ("suggestedCommands", "[String]?", false, "Executable follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}
