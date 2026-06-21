import Foundation
import TritonKitShared

func mapCommandSchemas() -> [TKCommandSchema] {
    let jsonText = ["json", "text"]
    let jsonAlias = TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --format json")
    return [
        TKCommandSchema(
            name: "map",
            summary: "Merge projected run evidence into a .tritonmap test path graph",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli-offline",
            outputFormats: jsonText,
            options: [
                TKCommandSchemaOption(name: "merge <dir.tritonevidence> --into <dir.tritonmap>", type: "Subcommand", description: "Merge one evidence run into an app map; auto-projects screens/transitions when missing"),
                TKCommandSchemaOption(name: "inspect <dir.tritonmap>", type: "Subcommand", description: "Inspect map counts and health"),
                TKCommandSchemaOption(name: "paths <dir.tritonmap>", type: "Subcommand", description: "List path graph assets"),
                TKCommandSchemaOption(name: "screens <dir.tritonmap>", type: "Subcommand", description: "List screen nodes"),
                TKCommandSchemaOption(name: "transitions <dir.tritonmap>", type: "Subcommand", description: "List transition edges"),
                TKCommandSchemaOption(name: "path show <dir.tritonmap> --path <pathId>", type: "Subcommand", description: "Show one path with screens and transitions"),
                TKCommandSchemaOption(name: "path confirm <dir.tritonmap> --path <pathId>", type: "Subcommand", description: "Confirm one observed path for suite eligibility"),
                TKCommandSchemaOption(name: "path unconfirm <dir.tritonmap> --path <pathId>", type: "Subcommand", description: "Unconfirm one path and remove it from suites"),
                TKCommandSchemaOption(name: "health <dir.tritonmap>", type: "Subcommand", description: "Inspect run health and coverage gaps"),
                TKCommandSchemaOption(name: "vlm-health <dir.tritonmap>", type: "Subcommand", description: "Inspect VLM provider health"),
                TKCommandSchemaOption(name: "suite inspect <dir.tritonmap> --suite <suiteId>", type: "Subcommand", description: "Inspect one suite"),
                TKCommandSchemaOption(name: "suite add-path <dir.tritonmap> --suite <suiteId> --path <pathId>", type: "Subcommand", description: "Add a confirmed replayable path to a suite"),
                TKCommandSchemaOption(name: "suite remove-path <dir.tritonmap> --suite <suiteId> --path <pathId>", type: "Subcommand", description: "Remove a path from a suite"),
                TKCommandSchemaOption(name: "suite run <dir.tritonmap> --suite <suiteId> --evidence-root <dir>", type: "Subcommand", description: "Run all paths in a suite, project evidence, and merge results back into the map"),
                TKCommandSchemaOption(name: "export-flow <dir.tritonmap> --path <pathId> --out <file.tritontest.yaml>", type: "Subcommand", description: "Export one path into a P0D-compatible .tritontest.yaml flow"),
                TKCommandSchemaOption(name: "viewer <dir.tritonmap> --output <file.html>", type: "Subcommand", description: "Export a static HTML App Map viewer"),
                TKCommandSchemaOption(name: "--into", type: "Path", description: "Output .tritonmap directory for merge"),
                TKCommandSchemaOption(name: "--confirm", type: "Bool", defaultValue: "false", description: "Confirm generated replayable paths for smoke suite inclusion"),
                TKCommandSchemaOption(name: "--path", type: "String", description: "Path id for export-flow"),
                TKCommandSchemaOption(name: "--suite", type: "String", defaultValue: "smoke", description: "Suite id for suite inspect"),
                TKCommandSchemaOption(name: "--evidence-root", type: "Path", description: "Output directory for suite run flows and .tritonevidence bundles"),
                TKCommandSchemaOption(name: "--target", type: "String", defaultValue: TKLocalTargetID, description: "Runtime target id for suite run"),
                TKCommandSchemaOption(name: "--host", type: "String", defaultValue: "127.0.0.1", description: "Triton HTTP host for suite run"),
                TKCommandSchemaOption(name: "--port", type: "Int", defaultValue: "19421", description: "Triton HTTP port for suite run"),
                TKCommandSchemaOption(name: "--allow-vlm", type: "Bool", defaultValue: "false", description: "Allow experimental VLM-assisted suite paths"),
                TKCommandSchemaOption(name: "--allow-remote-vlm", type: "Bool", defaultValue: "false", description: "Allow remote VLM provider calls for suite run"),
                TKCommandSchemaOption(name: "--vlm-base-url", type: "String", description: "OpenAI-compatible VLM base URL for suite run"),
                TKCommandSchemaOption(name: "--vlm-model", type: "String", description: "OpenAI-compatible VLM model for suite run"),
                TKCommandSchemaOption(name: "--vlm-api-key-env", type: "String", description: "Environment variable containing VLM API key for suite run"),
                TKCommandSchemaOption(name: "--provider", type: "String", description: "Filter VLM health to one provider"),
                TKCommandSchemaOption(name: "--screen", type: "String", description: "Filter VLM health to one screen id"),
                TKCommandSchemaOption(name: "--out", type: "Path", description: "Output .tritontest.yaml file for export-flow"),
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Output HTML file for viewer"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            usageForms: [
                TKCommandUsageForm(form: "merge <dir.tritonevidence> --into <dir.tritonmap> --json", kind: "Subcommand", description: "Merge run evidence into App Map assets"),
                TKCommandUsageForm(form: "inspect <dir.tritonmap> --json", kind: "Subcommand", description: "Read App Map counts and health"),
                TKCommandUsageForm(form: "paths <dir.tritonmap> --json", kind: "Subcommand", description: "List generated paths"),
                TKCommandUsageForm(form: "screens <dir.tritonmap> --json", kind: "Subcommand", description: "List screen nodes"),
                TKCommandUsageForm(form: "transitions <dir.tritonmap> --json", kind: "Subcommand", description: "List transition edges"),
                TKCommandUsageForm(form: "path show <dir.tritonmap> --path <pathId> --json", kind: "Subcommand", description: "Show one path with screens and transitions"),
                TKCommandUsageForm(form: "path confirm <dir.tritonmap> --path <pathId> --json", kind: "Subcommand", description: "Confirm an observed path"),
                TKCommandUsageForm(form: "path unconfirm <dir.tritonmap> --path <pathId> --json", kind: "Subcommand", description: "Unconfirm a path and remove it from suites"),
                TKCommandUsageForm(form: "health <dir.tritonmap> --json", kind: "Subcommand", description: "Inspect health and coverage gaps"),
                TKCommandUsageForm(form: "vlm-health <dir.tritonmap> --provider mlx-swift-lm --json", kind: "Subcommand", description: "Inspect VLM provider health"),
                TKCommandUsageForm(form: "suite inspect <dir.tritonmap> --suite smoke --json", kind: "Subcommand", description: "Inspect suite membership"),
                TKCommandUsageForm(form: "suite add-path <dir.tritonmap> --suite smoke --path <pathId> --json", kind: "Subcommand", description: "Add a confirmed path to a suite"),
                TKCommandUsageForm(form: "suite remove-path <dir.tritonmap> --suite smoke --path <pathId> --json", kind: "Subcommand", description: "Remove a path from a suite"),
                TKCommandUsageForm(form: "suite run <dir.tritonmap> --suite smoke --evidence-root <dir> --json", kind: "Subcommand", description: "Run confirmed suite paths and merge evidence back into the map"),
                TKCommandUsageForm(form: "export-flow <dir.tritonmap> --path <pathId> --out <file.tritontest.yaml> --json", kind: "Subcommand", description: "Export a replayable path to a test YAML"),
                TKCommandUsageForm(form: "viewer <dir.tritonmap> --output <file.html> --json", kind: "Subcommand", description: "Export a static HTML viewer for humans to inspect screens, transitions, and paths"),
            ],
            examples: [
                "triton map merge docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-pass.tritonevidence --into .tritonmap --json",
                "triton map inspect .tritonmap --json",
                "triton map paths .tritonmap --json",
                "triton map screens .tritonmap --json",
                "triton map transitions .tritonmap --json",
                "triton map path show .tritonmap --path path-fixture-login-home --json",
                "triton map path confirm .tritonmap --path path-fixture-login-home --json",
                "triton map suite add-path .tritonmap --suite smoke --path path-fixture-login-home --json",
                "triton map health .tritonmap --json",
                "triton map vlm-health .tritonmap --provider mlx-swift-lm --json",
                "triton map suite inspect .tritonmap --suite smoke --json",
                "triton map suite run .tritonmap --suite smoke --evidence-root evidence/smoke-run --json",
                "triton map export-flow .tritonmap --path path-fixture-login-home --out fixture-login-home.tritontest.yaml --json",
                "triton map viewer .tritonmap --output app-map.html --json",
            ],
            successShape: "TKAppMapMergeResponse, TKAppMapInspectResponse, TKAppMapPathsResponse, TKAppMapScreensResponse, TKAppMapTransitionsResponse, TKAppMapPathShowResponse, TKAppMapHealthResponse, TKAppMapSuiteInspectResponse, TKAppMapSuiteRunResponse, TKAppMapExportFlowResponse, or TKAppMapViewerResponse",
            failureShape: "{ ok:false, error:{ code: app_map_error, message, hint } }",
            outputSemantics: "Offline App Map projection and path planning only. It reads existing .tritonevidence and .tritonmap files; it can confirm paths, edit suite membership, and export a static HTML viewer, but it does not execute runner steps, devices, VLM, selector healing, Web/Wails control, or JUnit.",
            artifacts: ["app-map", "app-map.screens", "app-map.transitions", "app-map.paths", "app-map.suites", "tritontest-yaml", "app-map-viewer-html"],
            nextCommands: [
                "triton evidence project-workspace <dir.tritonevidence> --json",
                "triton map inspect <dir.tritonmap> --json",
                "triton map paths <dir.tritonmap> --json",
                "triton map health <dir.tritonmap> --json",
                "triton map suite inspect <dir.tritonmap> --suite smoke --json",
                "triton test validate <file.tritontest.yaml> --json",
            ],
            outputContracts: [
                appMapMergeOutputContract(),
                appMapInspectOutputContract(),
                appMapPathsOutputContract(),
                appMapScreensOutputContract(),
                appMapTransitionsOutputContract(),
                appMapPathShowOutputContract(),
                appMapHealthOutputContract(),
                appMapVLMHealthOutputContract(),
                appMapSuiteInspectOutputContract(),
                appMapSuiteRunOutputContract(),
                appMapExportFlowOutputContract(),
                appMapViewerOutputContract(),
            ],
            failureCodes: ["app_map_error", "validation_failed", "unconfirmed_path", "non_replayable_path"],
            subcommands: [
                TKCommandSubcommandSchema(
                    name: "merge",
                    summary: "Merge a .tritonevidence run into a .tritonmap directory",
                    requiredOptions: ["--into"],
                    optionalOptions: ["--confirm", "--format", "--json"],
                    artifacts: ["app-map", "app-map.screens", "app-map.transitions", "app-map.paths", "app-map.suites"],
                    nextCommands: [
                        "triton map inspect <dir.tritonmap> --json",
                        "triton map export-flow <dir.tritonmap> --path <pathId> --out <file.tritontest.yaml> --json",
                    ],
                    outputSelectors: ["app-map.merge"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "inspect",
                    summary: "Inspect a .tritonmap directory",
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map"],
                    nextCommands: [
                        "triton map paths <dir.tritonmap> --json",
                    ],
                    outputSelectors: ["app-map.inspect"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "paths",
                    summary: "List path graph assets",
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map.paths"],
                    nextCommands: [
                        "triton map export-flow <dir.tritonmap> --path <pathId> --out <file.tritontest.yaml> --json",
                    ],
                    outputSelectors: ["app-map.paths"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "screens",
                    summary: "List screen nodes",
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map.screens"],
                    nextCommands: [
                        "triton map health <dir.tritonmap> --json",
                    ],
                    outputSelectors: ["app-map.screens"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "transitions",
                    summary: "List transition edges",
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map.transitions"],
                    nextCommands: [
                        "triton map path show <dir.tritonmap> --path <pathId> --json",
                    ],
                    outputSelectors: ["app-map.transitions"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "path",
                    summary: "Inspect or confirm one path",
                    requiredOptions: ["--path"],
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map.paths", "app-map.screens", "app-map.transitions"],
                    nextCommands: [
                        "triton map path confirm <dir.tritonmap> --path <pathId> --json",
                        "triton map suite add-path <dir.tritonmap> --suite smoke --path <pathId> --json",
                        "triton map export-flow <dir.tritonmap> --path <pathId> --out <file.tritontest.yaml> --json",
                    ],
                    outputSelectors: ["app-map.path-show"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "health",
                    summary: "Inspect App Map health and coverage gaps",
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map", "app-map.paths"],
                    nextCommands: [
                        "triton map paths <dir.tritonmap> --json",
                    ],
                    outputSelectors: ["app-map.health"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "vlm-health",
                    summary: "Inspect VLM provider health projected from App Map evidence",
                    optionalOptions: ["--provider", "--screen", "--format", "--json"],
                    artifacts: ["app-map", "app-map.paths", "app-map.screens", "app-map.transitions"],
                    nextCommands: [
                        "triton map paths <dir.tritonmap> --json",
                        "triton map viewer <dir.tritonmap> --output <file.html> --json",
                    ],
                    outputSelectors: ["app-map.vlm-health"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "suite",
                    summary: "Inspect, edit, and run suite membership",
                    requiredOptions: [],
                    optionalOptions: ["--suite", "--path", "--evidence-root", "--target", "--host", "--port", "--allow-vlm", "--allow-remote-vlm", "--vlm-base-url", "--vlm-model", "--vlm-api-key-env", "--format", "--json"],
                    artifacts: ["app-map.suites", "app-map.paths"],
                    nextCommands: [
                        "triton map suite add-path <dir.tritonmap> --suite smoke --path <pathId> --json",
                        "triton map suite remove-path <dir.tritonmap> --suite smoke --path <pathId> --json",
                        "triton map suite run <dir.tritonmap> --suite smoke --evidence-root <dir> --json",
                        "triton map path show <dir.tritonmap> --path <pathId> --json",
                    ],
                    outputSelectors: ["app-map.suite-inspect", "app-map.suite-run"],
                    failureCodes: ["app_map_error", "unconfirmed_path", "non_replayable_path"]
                ),
                TKCommandSubcommandSchema(
                    name: "export-flow",
                    summary: "Export a path to .tritontest.yaml",
                    requiredOptions: ["--path", "--out"],
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["tritontest-yaml"],
                    nextCommands: [
                        "triton test validate <file.tritontest.yaml> --json",
                        "triton test run <file.tritontest.yaml> --json --evidence-dir <dir.tritonevidence>",
                    ],
                    outputSelectors: ["app-map.export-flow"],
                    failureCodes: ["app_map_error"]
                ),
                TKCommandSubcommandSchema(
                    name: "viewer",
                    summary: "Export a static HTML App Map viewer",
                    requiredOptions: ["--output"],
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map-viewer-html"],
                    nextCommands: [
                        "triton map inspect <dir.tritonmap> --json",
                    ],
                    outputSelectors: ["app-map.viewer"],
                    failureCodes: ["app_map_error"]
                ),
            ],
            providedCapabilities: ["app-map-merge", "app-map-inspect", "app-map-paths", "app-map-screens", "app-map-transitions", "app-map-path-show", "app-map-path-confirm", "app-map-suite-inspect", "app-map-suite-edit", "app-map-suite-run", "app-map-health", "app-map-vlm-health", "app-map-export-flow", "app-map-viewer"]
        ),
    ]
}
