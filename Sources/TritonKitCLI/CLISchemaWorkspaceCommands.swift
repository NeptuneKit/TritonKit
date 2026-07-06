import Foundation
import TritonKitShared

func workspaceCommandSchemas() -> [TKCommandSchema] {
    [
        TKCommandSchema(
            name: "workspace",
            summary: "Create and inspect local agent workspace runs",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "local workspace",
            outputFormats: ["json", "text"],
            options: [
                TKCommandSchemaOption(name: "run", type: "Subcommand", description: "Create .triton/runs/<run-id> with the first workspace facts"),
                TKCommandSchemaOption(name: "inspect <run-id>", type: "Subcommand", description: "Read run.json and events.jsonl"),
                TKCommandSchemaOption(name: "stop <run-id>", type: "Subcommand", description: "Append run.stopped if the run is not already stopped"),
                TKCommandSchemaOption(name: "export-flow <run-id>", type: "Subcommand", description: "Write a .tritonflow.yaml seed from run facts"),
                TKCommandSchemaOption(name: "--target", type: "String", defaultValue: "current", description: "Target selector recorded in the run"),
                TKCommandSchemaOption(name: "--app", type: "String", description: "App artifact, bundle id, package name, or app id"),
                TKCommandSchemaOption(name: "--goal", type: "String", description: "Natural-language run goal"),
                TKCommandSchemaOption(name: "--runs-dir", type: "Path", defaultValue: ".triton/runs", description: "Workspace run root"),
                TKCommandSchemaOption(name: "--run-id", type: "String", description: "Optional stable run id"),
                TKCommandSchemaOption(name: "--action-policy", type: "explore|planFirst", defaultValue: "explore", description: "Runner action policy recorded in config.yaml"),
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Output .tritonflow.yaml path for export-flow"),
                schemaFormatJSONTextOption,
                schemaJSONAliasOption,
            ],
            usageForms: [
                TKCommandUsageForm(form: "run --target current --app <app> --goal <goal> --json", kind: "Subcommand", description: "Create a local workspace run facts directory"),
                TKCommandUsageForm(form: "inspect <run-id> --json", kind: "Subcommand", description: "Read run status and event summary"),
                TKCommandUsageForm(form: "stop <run-id> --json", kind: "Subcommand", description: "Stop a run idempotently"),
                TKCommandUsageForm(form: "export-flow <run-id> --output <file.tritonflow.yaml> --json", kind: "Subcommand", description: "Export a flow seed from run facts"),
            ],
            argumentForms: [
                TKCommandArgumentForm(name: "<run-id>", type: "String", required: true, description: "Workspace run id under --runs-dir"),
            ],
            examples: [
                #"triton workspace run --target current --app com.example.demo --goal "Explore login" --json"#,
                "triton workspace inspect run_123 --json",
                "triton workspace stop run_123 --json",
                "triton workspace export-flow run_123 --output flow.tritonflow.yaml --json",
            ],
            successShape: "run emits triton.workspace.run; inspect/stop emit triton.workspace.inspect; export-flow emits triton.workspace.export-flow",
            outputSemantics: "workspace run is the local Run entry. The first implementation writes .triton/runs/<run-id>/run.json, config.yaml, events.jsonl, report.json, evidence placeholders, atlas/atlas.json, default llm/vlm enabled state, provider missing nextAction, and flow.bootstrap.checked. It does not claim a real device action or model decision until providers and target execution are wired.",
            jsonlEvents: [
                "run.started",
                "target.resolved",
                "provider.checked",
                "app.ready",
                "observation.captured",
                "flow.bootstrap.checked",
                "run.stopped",
            ],
            finalEventKind: "run.stopped",
            artifacts: [
                ".triton/runs/<run-id>/run.json",
                ".triton/runs/<run-id>/config.yaml",
                ".triton/runs/<run-id>/events.jsonl",
                ".triton/runs/<run-id>/report.json",
                ".triton/runs/<run-id>/atlas/atlas.json",
            ],
            failureCodes: ["workspace_failed"],
            subcommands: [
                TKCommandSubcommandSchema(
                    name: "run",
                    summary: "Create a local workspace run facts directory",
                    requiredOptions: ["--app", "--goal"],
                    optionalOptions: ["--target", "--runs-dir", "--run-id", "--action-policy", "--format", "--json"],
                    jsonlEvents: ["run.started", "target.resolved", "provider.checked", "app.ready", "observation.captured", "flow.bootstrap.checked", "run.stopped"],
                    finalEventKind: "run.stopped",
                    artifacts: ["run.json", "config.yaml", "events.jsonl", "report.json", "atlas/atlas.json"],
                    outputSelectors: ["workspace.run"],
                    failureCodes: ["workspace_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "inspect",
                    summary: "Read a local workspace run",
                    requiredOptions: ["<run-id>"],
                    optionalOptions: ["--runs-dir", "--format", "--json"],
                    outputSelectors: ["workspace.inspect"],
                    failureCodes: ["workspace_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "stop",
                    summary: "Stop a local workspace run idempotently",
                    requiredOptions: ["<run-id>"],
                    optionalOptions: ["--runs-dir", "--format", "--json"],
                    outputSelectors: ["workspace.inspect"],
                    failureCodes: ["workspace_failed"]
                ),
                TKCommandSubcommandSchema(
                    name: "export-flow",
                    summary: "Export a .tritonflow.yaml seed from a local workspace run",
                    requiredOptions: ["<run-id>", "--output"],
                    optionalOptions: ["--runs-dir", "--format", "--json"],
                    outputSelectors: ["workspace.export-flow"],
                    failureCodes: ["workspace_failed"]
                ),
            ]
        ),
    ]
}
