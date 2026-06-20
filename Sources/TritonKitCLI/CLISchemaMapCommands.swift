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
                TKCommandSchemaOption(name: "health <dir.tritonmap>", type: "Subcommand", description: "Inspect run health and coverage gaps"),
                TKCommandSchemaOption(name: "suite inspect <dir.tritonmap> --suite <suiteId>", type: "Subcommand", description: "Inspect one suite"),
                TKCommandSchemaOption(name: "export-flow <dir.tritonmap> --path <pathId> --out <file.tritontest.yaml>", type: "Subcommand", description: "Export one path into a P0D-compatible .tritontest.yaml flow"),
                TKCommandSchemaOption(name: "--into", type: "Path", description: "Output .tritonmap directory for merge"),
                TKCommandSchemaOption(name: "--confirm", type: "Bool", defaultValue: "false", description: "Confirm generated replayable paths for smoke suite inclusion"),
                TKCommandSchemaOption(name: "--path", type: "String", description: "Path id for export-flow"),
                TKCommandSchemaOption(name: "--suite", type: "String", defaultValue: "smoke", description: "Suite id for suite inspect"),
                TKCommandSchemaOption(name: "--out", type: "Path", description: "Output .tritontest.yaml file for export-flow"),
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
                TKCommandUsageForm(form: "health <dir.tritonmap> --json", kind: "Subcommand", description: "Inspect health and coverage gaps"),
                TKCommandUsageForm(form: "suite inspect <dir.tritonmap> --suite smoke --json", kind: "Subcommand", description: "Inspect suite membership"),
                TKCommandUsageForm(form: "export-flow <dir.tritonmap> --path <pathId> --out <file.tritontest.yaml> --json", kind: "Subcommand", description: "Export a replayable path to a test YAML"),
            ],
            examples: [
                "triton map merge docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-pass.tritonevidence --into .tritonmap --json",
                "triton map inspect .tritonmap --json",
                "triton map paths .tritonmap --json",
                "triton map screens .tritonmap --json",
                "triton map transitions .tritonmap --json",
                "triton map path show .tritonmap --path path-fixture-login-home --json",
                "triton map health .tritonmap --json",
                "triton map suite inspect .tritonmap --suite smoke --json",
                "triton map export-flow .tritonmap --path path-fixture-login-home --out fixture-login-home.tritontest.yaml --json",
            ],
            successShape: "TKAppMapMergeResponse, TKAppMapInspectResponse, TKAppMapPathsResponse, TKAppMapScreensResponse, TKAppMapTransitionsResponse, TKAppMapPathShowResponse, TKAppMapHealthResponse, TKAppMapSuiteInspectResponse, or TKAppMapExportFlowResponse",
            failureShape: "{ ok:false, error:{ code: app_map_error, message, hint } }",
            outputSemantics: "Offline App Map projection only. It reads existing .tritonevidence and .tritonmap files; it does not execute runner steps, devices, VLM, selector healing, HTML, or JUnit.",
            artifacts: ["app-map", "app-map.screens", "app-map.transitions", "app-map.paths", "app-map.suites", "tritontest-yaml"],
            nextCommands: [
                "triton evidence project-workspace <dir.tritonevidence> --json",
                "triton map inspect <dir.tritonmap> --json",
                "triton map paths <dir.tritonmap> --json",
                "triton map health <dir.tritonmap> --json",
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
                appMapSuiteInspectOutputContract(),
                appMapExportFlowOutputContract(),
            ],
            failureCodes: ["app_map_error", "validation_failed"],
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
                    summary: "Inspect one path",
                    requiredOptions: ["--path"],
                    optionalOptions: ["--format", "--json"],
                    artifacts: ["app-map.paths", "app-map.screens", "app-map.transitions"],
                    nextCommands: [
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
                    name: "suite",
                    summary: "Inspect suite membership",
                    requiredOptions: [],
                    optionalOptions: ["--suite", "--format", "--json"],
                    artifacts: ["app-map.suites", "app-map.paths"],
                    nextCommands: [
                        "triton map path show <dir.tritonmap> --path <pathId> --json",
                    ],
                    outputSelectors: ["app-map.suite-inspect"],
                    failureCodes: ["app_map_error"]
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
            ],
            providedCapabilities: ["app-map-merge", "app-map-inspect", "app-map-paths", "app-map-screens", "app-map-transitions", "app-map-path-show", "app-map-health", "app-map-suite-inspect", "app-map-export-flow"]
        ),
    ]
}
