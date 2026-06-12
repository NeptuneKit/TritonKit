import Foundation
import TritonKitShared

private func nextActionSchemaFields(
    name: String,
    required: Bool,
    description: String
) -> [TKCommandSchemaField] {
    [
        TKCommandSchemaField(name: name, type: "TKCLINextAction?", required: required, description: description),
        TKCommandSchemaField(
            name: "\(name).command",
            type: "String",
            required: true,
            description: "Suggested Triton command root for the next action"
        ),
        TKCommandSchemaField(
            name: "\(name).args",
            type: "[String]",
            required: true,
            description: "Suggested command arguments for the next action"
        ),
        TKCommandSchemaField(
            name: "\(name).category",
            type: "String",
            required: true,
            description: "Recovery category derived from the next action command root"
        ),
        TKCommandSchemaField(
            name: "\(name).requiresLongRunningProcess",
            type: "Bool",
            required: true,
            description: "Whether the next action starts a long-running process"
        ),
        TKCommandSchemaField(
            name: "\(name).readyEvents",
            type: "[String]",
            required: true,
            description: "JSONL events that prove a long-running next action is ready for dependent actions"
        ),
        TKCommandSchemaField(
            name: "\(name).finalEvents",
            type: "[String]",
            required: true,
            description: "JSONL events expected when a long-running next action exits cleanly"
        ),
        TKCommandSchemaField(
            name: "\(name).terminationSignals",
            type: "[String]",
            required: true,
            description: "Preferred signals for agents to stop a long-running next action after dependent work finishes"
        ),
    ]
}

func schemaContractFields(_ specs: [(String, String, Bool, String)]) -> [TKCommandSchemaField] {
    specs.flatMap { spec -> [TKCommandSchemaField] in
        let field = TKCommandSchemaField(name: spec.0, type: spec.1, required: spec.2, description: spec.3)
        if spec.0 == "error", spec.1 == "TKCLIErrorDetail?" {
            return [
                field,
                TKCommandSchemaField(
                    name: "error.endpoint",
                    type: "String?",
                    required: false,
                    description: "Associated endpoint when the failure came from runtime transport or another addressable surface"
                ),
                TKCommandSchemaField(
                    name: "error.hint",
                    type: "String?",
                    required: false,
                    description: "Suggested diagnostic hint for the failure"
                ),
                TKCommandSchemaField(
                    name: "error.nearestCandidates",
                    type: "[String]?",
                    required: false,
                    description: "Nearest candidate strings when the failure exposes selector or text alternatives"
                ),
                TKCommandSchemaField(
                    name: "error.suggestedCommands",
                    type: "[String]?",
                    required: false,
                    description: "Command suggestions bundled directly inside the failure diagnostic"
                ),
                TKCommandSchemaField(
                    name: "error.candidateCount",
                    type: "Int?",
                    required: false,
                    description: "Candidate count associated with the failure diagnostic"
                ),
            ] + nextActionSchemaFields(
                name: "error.nextAction",
                required: false,
                description: "Recommended recovery command when the failure is actionable"
            )
        }
        if spec.1 == "TKCLINextAction?" {
            return nextActionSchemaFields(name: spec.0, required: spec.2, description: spec.3)
        }
        return [field]
    }
}
