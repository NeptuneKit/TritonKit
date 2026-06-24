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
