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
            ("ok", "Bool", true, "Whether every matrix target is ready or passed"),
            ("schemaVersion", "Int?", false, "Matrix response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.matrix when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("executor", "String?", false, "Executor used for every target; null means dry-run matrix"),
            ("evidenceRoot", "String?", false, "Optional root directory used to write per-target evidence bundles"),
            ("status", "String?", false, "Aggregated matrix status: ready, passed, or blocked"),
            ("targetCount", "Int?", false, "Number of matrix targets"),
            ("readyCount", "Int?", false, "Number of dry-run targets ready for replay"),
            ("passedCount", "Int?", false, "Number of local-simulated targets passed"),
            ("blockedCount", "Int?", false, "Number of blocked targets"),
            ("results", "[TKTestRecorderMatrixTargetResult]?", false, "Per-target replay plan or local-simulated summary"),
            ("results[].target", "String?", false, "Original platform[:device] target selector"),
            ("results[].platform", "String?", false, "Target platform"),
            ("results[].device", "String?", false, "Optional target device selector"),
            ("results[].status", "String?", false, "Per-target status: ready, passed, or blocked"),
            ("results[].dryRun", "Bool?", false, "Whether this target only planned replay"),
            ("results[].plannedStepCount", "Int?", false, "Planned or simulated step count"),
            ("results[].evidenceDir", "String?", false, "Per-target evidence bundle directory when local-simulated matrix evidence was requested"),
            ("results[].blockers", "[TKTestRecorderReplayBlocker]?", false, "Per-target blockers"),
            ("suggestedCommands", "[String]?", false, "Executable follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}
