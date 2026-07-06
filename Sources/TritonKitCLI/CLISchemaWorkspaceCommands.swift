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
                TKCommandSchemaOption(name: "--platform", type: "ios|android|harmony|unknown", defaultValue: "unknown", description: "Target platform fact recorded in run target metadata"),
                TKCommandSchemaOption(name: "--scope", type: "simulator|emulator|real|current", defaultValue: "current", description: "Target scope fact recorded in run target metadata"),
                TKCommandSchemaOption(name: "--app", type: "String", description: "App artifact, bundle id, package name, or app id"),
                TKCommandSchemaOption(name: "--goal", type: "String", description: "Natural-language run goal"),
                TKCommandSchemaOption(name: "--runs-dir", type: "Path", defaultValue: ".triton/runs", description: "Workspace run root"),
                TKCommandSchemaOption(name: "--run-id", type: "String", description: "Optional stable run id"),
                TKCommandSchemaOption(name: "--action-policy", type: "explore|planFirst", defaultValue: "explore", description: "Runner action policy recorded in config.yaml"),
                TKCommandSchemaOption(name: "--max-steps", type: "Int", defaultValue: "20", description: "Maximum bounded runner steps before max_steps_reached"),
                TKCommandSchemaOption(name: "--allowed-action", type: "String[]", defaultValue: "tap,swipe,type,wait,verify,stop", description: "Allowed runner action; repeat to override the default action allowlist"),
                TKCommandSchemaOption(name: "--stop-condition", type: "String[]", defaultValue: "max_steps_reached,provider_missing,unsupported_capability,policy_rejected,model_unparseable", description: "Runner stop condition; repeat to override the default stop set"),
                TKCommandSchemaOption(name: "--llm-provider", type: "String", description: "Optional LLM provider id to preflight for workspace bootstrap"),
                TKCommandSchemaOption(name: "--vlm-provider", type: "String", description: "Optional VLM provider id to preflight for workspace bootstrap"),
                TKCommandSchemaOption(name: "--dry-model-fixture", type: "Bool", defaultValue: "false", description: "Append dry model/policy/action/recovery events without calling a model or device"),
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
            outputSemantics: "workspace run is the local Run entry. It writes .triton/runs/<run-id>/run.json, config.yaml, events.jsonl, report.json, evidence placeholders, atlas/atlas.json, runner bounds, default llm/vlm enabled state, provider preflight nextActions, and flow.bootstrap.checked. workspace inspect returns run status, event summary, latest bootstrap, and Atlas coverage summary. It does not claim a real device action or model decision until providers and target execution are wired.",
            jsonlEvents: [
                "run.started",
                "target.resolved",
                "provider.checked",
                "app.ready",
                "observation.captured",
                "flow.bootstrap.checked",
                "model.decided",
                "policy.checked",
                "action.executed",
                "verify.checked",
                "flow.recovery.detected",
                "flow.recovery.proposed",
                "flow.recovery.rejected",
                "atlas.updated",
                "flow.updated",
                "run.paused",
                "run.stopped",
            ],
            finalEventKind: "run.paused|run.stopped",
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
                    optionalOptions: ["--target", "--platform", "--scope", "--runs-dir", "--run-id", "--action-policy", "--max-steps", "--allowed-action", "--stop-condition", "--llm-provider", "--vlm-provider", "--dry-model-fixture", "--format", "--json"],
                    jsonlEvents: ["run.started", "target.resolved", "provider.checked", "app.ready", "observation.captured", "flow.bootstrap.checked", "model.decided", "policy.checked", "action.executed", "verify.checked", "flow.recovery.detected", "flow.recovery.proposed", "flow.recovery.rejected", "atlas.updated", "flow.updated", "run.paused", "run.stopped"],
                    finalEventKind: "run.paused|run.stopped",
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
