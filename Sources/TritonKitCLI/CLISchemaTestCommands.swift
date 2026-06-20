import Foundation
import TritonKitShared

func testCommandSchemas() -> [TKCommandSchema] {
    [
        TKCommandSchema(
            name: "test",
            summary: "Validate, normalize, and minimally execute .tritontest.yaml contracts",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "offline for validate/normalize; runtime target required for run",
            exitCodeOnFailure: 1,
            outputFormats: ["json", "text"],
            options: [
                TKCommandSchemaOption(name: "validate <path.tritontest.yaml>", type: "Subcommand", description: "Validate a .tritontest.yaml file"),
                TKCommandSchemaOption(name: "normalize <path.tritontest.yaml>", type: "Subcommand", description: "Validate and emit only the normalized plan"),
                TKCommandSchemaOption(name: "run <path.tritontest.yaml>", type: "Subcommand", description: "Run the P0E minimal executor after validate/normalize and capture screen workspace readiness observations"),
                TKCommandSchemaOption(name: "--evidence-dir", type: "Path", description: "Required for run; output .tritonevidence directory"),
                TKCommandSchemaOption(name: "--target", type: "String", defaultValue: TKLocalTargetID, description: "Runtime target id for run"),
                TKCommandSchemaOption(name: "--host", type: "String", defaultValue: "127.0.0.1", description: "Triton HTTP host for run"),
                TKCommandSchemaOption(name: "--port", type: "Int", defaultValue: "19421", description: "Triton HTTP port for run"),
                TKCommandSchemaOption(name: "--emit-normalized-plan", type: "Bool", defaultValue: "false", description: "Emit only normalizedPlan for validate when validation succeeds"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                schemaJSONAliasOption,
            ],
            usageForms: [
                TKCommandUsageForm(form: "validate <path.tritontest.yaml> --json", kind: "Subcommand", description: "Validate and emit { ok, normalizedPlan }"),
                TKCommandUsageForm(form: "validate <path.tritontest.yaml> --emit-normalized-plan --json", kind: "Subcommand", description: "Validate and emit only triton.test.normalized-plan JSON"),
                TKCommandUsageForm(form: "normalize <path.tritontest.yaml> --json", kind: "Subcommand", description: "Alias for validate --emit-normalized-plan"),
                TKCommandUsageForm(form: "run <path.tritontest.yaml> --json --evidence-dir <dir>", kind: "Subcommand", description: "Validate, execute launch/takeScreenshot/tap(point)/assertVisible(ax exact), and write .tritonevidence/run/events.jsonl plus observation.captured events"),
            ],
            argumentForms: [
                TKCommandArgumentForm(name: "<path.tritontest.yaml>", type: "Path", required: true, description: "Input .tritontest.yaml contract file"),
            ],
            examples: [
                "triton test validate login.tritontest.yaml --json",
                "triton test validate login.tritontest.yaml --emit-normalized-plan --json",
                "triton test normalize login.tritontest.yaml --json",
                "triton test run login.tritontest.yaml --json --evidence-dir ./login.tritonevidence",
            ],
            successShape: "validate emits TKTestValidationResponse; normalize emits TKTestNormalizedPlan; run emits TKTestRunExecutionResponse with normalizedPlan, run metadata, event summary, observationCount, and evidenceDir.",
            failureShape: "{ ok:false, error:{ type:\"validation_error\", message, path, code, allowed? } }",
            outputSemantics: "P0E run first reuses P0B validate/normalize. Only launch, takeScreenshot, tap(point/runtime-point), and assertVisible(text/source=ax/match=exact) execute. The runner writes observation.captured events with screenshot, AX, hierarchy, screenCandidate fingerprints, and coordinate-contract.json so P1 can derive screen workspace evidence later. Unsupported steps remain validation_error and do not trigger device operations. P0E does not implement tap(text), input, swipe, VLM, App Map, replay, screens/transitions, selector healing, HTML, or JUnit.",
            nextCommands: [
                "triton schema --command test --json",
            ],
            outputContracts: [
                testValidationOutputContract(),
                testNormalizedPlanOutputContract(),
                testRunOutputContract(),
            ],
            failureCodes: [
                "unknown_step",
                "missing_required_field",
                "invalid_point",
                "unsupported_step",
                "unsupported_selector",
                "unsupported_coordinate_space",
                "invalid_optional_type",
                "invalid_timeout",
                "duplicate_step_id",
                "invalid_app_bundle_id",
                "invalid_yaml",
                "unsupported_schema_version",
                "validation_error",
                "launch_failed",
                "tap_failed",
                "assert_visible_failed",
                "primitive_failed",
            ],
            subcommands: [
                TKCommandSubcommandSchema(
                    name: "validate",
                    summary: "Validate a .tritontest.yaml file and emit a normalized offline plan",
                    requiredOptions: ["<path.tritontest.yaml>"],
                    optionalOptions: ["--format", "--json", "--emit-normalized-plan"],
                    nextCommands: [
                        "triton schema --command test --json",
                    ],
                    outputSelectors: ["test.validation", "test.normalized-plan"],
                    failureCodes: [
                        "unknown_step",
                        "missing_required_field",
                        "invalid_point",
                        "unsupported_step",
                        "unsupported_selector",
                        "unsupported_coordinate_space",
                        "invalid_optional_type",
                        "invalid_timeout",
                        "duplicate_step_id",
                        "invalid_app_bundle_id",
                        "invalid_yaml",
                        "unsupported_schema_version",
                    ]
                ),
                TKCommandSubcommandSchema(
                    name: "normalize",
                    summary: "Validate a .tritontest.yaml file and emit only the normalized plan",
                    requiredOptions: ["<path.tritontest.yaml>"],
                    optionalOptions: ["--format", "--json"],
                    nextCommands: [
                        "triton schema --command test --json",
                    ],
                    outputSelectors: ["test.normalized-plan"],
                    failureCodes: [
                        "unknown_step",
                        "missing_required_field",
                        "invalid_point",
                        "unsupported_step",
                        "unsupported_selector",
                        "unsupported_coordinate_space",
                        "invalid_optional_type",
                        "invalid_timeout",
                        "duplicate_step_id",
                        "invalid_app_bundle_id",
                        "invalid_yaml",
                        "unsupported_schema_version",
                    ]
                ),
                TKCommandSubcommandSchema(
                    name: "run",
                    summary: "Validate, normalize, execute the P0E minimal step set, and write .tritonevidence observations",
                    requiredOptions: ["<path.tritontest.yaml>", "--evidence-dir"],
                    optionalOptions: ["--target", "--host", "--port", "--format", "--json"],
                    nextCommands: [
                        "triton evidence summary <dir> --json",
                    ],
                    outputSelectors: ["test.run-result", "test.validation", "test.normalized-plan"],
                    failureCodes: [
                        "validation_error",
                        "unsupported_step",
                        "unsupported_coordinate_space",
                        "unsupported_selector",
                        "launch_failed",
                        "tap_failed",
                        "assert_visible_failed",
                        "primitive_failed",
                    ]
                ),
            ],
            providedCapabilities: ["test-validate", "test-normalized-plan", "test-run-minimal"]
        ),
    ]
}
