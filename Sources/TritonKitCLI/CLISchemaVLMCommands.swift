import Foundation
import TritonKitShared

func vlmCommandSchemas() -> [TKCommandSchema] {
    [
        TKCommandSchema(
            name: "vlm",
            summary: "Ground VLM targets against screenshot evidence without device operations",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli-offline",
            outputFormats: schemaTextJSONFormats,
            options: [
                TKCommandSchemaOption(name: "ground", type: "Subcommand", description: "Ground a target phrase using mock, OpenAI-compatible, or local MLX Swift providers"),
                TKCommandSchemaOption(name: "providers", type: "Subcommand", description: "List available VLM grounding providers"),
                TKCommandSchemaOption(name: "--provider", type: "mock|openai-compatible|mlx-swift-lm", defaultValue: "mock", description: "Grounding provider"),
                TKCommandSchemaOption(name: "--image", type: "Path", required: true, description: "Screenshot artifact path"),
                TKCommandSchemaOption(name: "--target", type: "String", required: true, description: "Target phrase to ground"),
                TKCommandSchemaOption(name: "--coordinate-contract", type: "Path", required: true, description: "P0E coordinate-contract.json path"),
                TKCommandSchemaOption(name: "--base-url", type: "URL", description: "OpenAI-compatible /v1 base URL; required for openai-compatible"),
                TKCommandSchemaOption(name: "--model", type: "String", defaultValue: "vlm-grounding", description: "Provider model id"),
                TKCommandSchemaOption(name: "--model-path", type: "Path", description: "Local mlx-swift-lm model path"),
                TKCommandSchemaOption(name: "--api-key-env", type: "String", description: "Environment variable containing provider API key"),
                TKCommandSchemaOption(name: "--allow-remote-vlm", type: "Bool", defaultValue: "false", description: "Allow non-localhost VLM provider requests"),
                TKCommandSchemaOption(name: "--max-tokens", type: "Int", defaultValue: "64", description: "Maximum provider output tokens"),
                TKCommandSchemaOption(name: "--temperature", type: "Double", defaultValue: "0", description: "Provider sampling temperature"),
                TKCommandSchemaOption(name: "--seed", type: "Int", defaultValue: "0", description: "Provider seed"),
                TKCommandSchemaOption(name: "--prompt-template", type: "String", defaultValue: "gui-grounding-v1", description: "Prompt template id"),
                TKCommandSchemaOption(name: "--allow-model-download", type: "Bool", defaultValue: "false", description: "Allow local provider model download"),
                TKCommandSchemaOption(name: "--no-model-download", type: "Bool", defaultValue: "false", description: "Keep local provider model download disabled"),
                TKCommandSchemaOption(name: "--output-dir", type: "Path", description: "Directory for overlay/request/response artifacts"),
                schemaFormatJSONTextOption,
                schemaJSONAliasOption,
            ],
            usageForms: [
                TKCommandUsageForm(
                    form: "ground --provider mock --image <screenshot.png> --target <text> --coordinate-contract <coordinate-contract.json>",
                    kind: "Subcommand",
                    description: "Produces runtime-point grounding and overlay evidence without network or device access"
                ),
                TKCommandUsageForm(
                    form: "ground --provider openai-compatible --base-url <http://127.0.0.1:8000/v1> --model <model> --image <screenshot.png> --target <text> --coordinate-contract <coordinate-contract.json>",
                    kind: "Subcommand",
                    description: "Calls a localhost OpenAI-compatible point-grounding endpoint and records redacted artifacts"
                ),
                TKCommandUsageForm(
                    form: "ground --provider mlx-swift-lm --model-path <local-model> --image <screenshot.png> --target <text> --coordinate-contract <coordinate-contract.json>",
                    kind: "Subcommand",
                    description: "Runs the P17 local MLX provider contract through a deterministic fake helper and records full grounding artifacts"
                ),
                TKCommandUsageForm(
                    form: "providers --json",
                    kind: "Subcommand",
                    description: "Lists mock, openai-compatible, and mlx-swift-lm provider metadata"
                ),
            ],
            examples: [
                "triton vlm ground --provider mock --image debug/step-003-after.png --target 'Go Home button' --coordinate-contract coordinate-contract.json --json",
                "triton vlm ground --provider openai-compatible --base-url http://127.0.0.1:8000/v1 --model UGround-V1-7B --image debug/step-003-after.png --target 'Go Home button' --coordinate-contract coordinate-contract.json --json",
                "triton vlm ground --provider mlx-swift-lm --model-path ~/.cache/triton/mlx-models/gui-grounding-vlm --image debug/step-003-after.png --target 'Go Home button' --coordinate-contract coordinate-contract.json --json",
                "triton vlm providers --json",
            ],
            successShape: "{ ok, provider, target, image, coordinateContract, point{ normalized, runtimePoint, coordinateSpace }, transform, artifacts{ overlay, request, response, rawOutput?, parsedPoint?, transform?, modelMetadata? } } or providers list",
            outputSemantics: "offline-only; no network, no API key, no device action; point output is runtime-point derived from coordinate-contract.json",
            artifacts: ["vlm-grounding", "vlm-overlay", "vlm-request", "vlm-response", "vlm-raw-output", "vlm-parsed-point", "vlm-transform", "vlm-model-metadata", "coordinate-contract", "screenshot"],
            nextCommands: [
                "triton schema --command vlm --json",
            ],
            outputContracts: [
                vlmGroundOutputContract(),
                vlmProvidersOutputContract(),
            ],
            failureCodes: [
                "vlm_unsupported_provider",
                "vlm_openai_base_url_required",
                "vlm_openai_base_url_invalid",
                "vlm_remote_provider_requires_approval",
                "vlm_api_key_missing",
                "vlm_provider_request_invalid",
                "vlm_provider_request_failed",
                "vlm_provider_response_invalid",
                "vlm_provider_point_parse_failed",
                "mlx_model_load_failed",
                "mlx_generation_failed",
                "mlx_response_empty",
                "mlx_parse_failed",
                "vlm_target_not_visible",
                "vlm_image_not_found",
                "vlm_image_metadata_unavailable",
                "vlm_coordinate_contract_not_found",
                "vlm_coordinate_contract_invalid",
                "vlm_coordinate_space_unsupported",
                "vlm_point_out_of_bounds",
                "vlm_overlay_failed",
                "vlm_artifact_write_failed",
                "vlm_grounding_failed",
            ],
            subcommands: [
                TKCommandSubcommandSchema(
                    name: "ground",
                    summary: "Resolve a target phrase to a runtime-point with mock, OpenAI-compatible, or local MLX Swift VLM grounding",
                    requiredOptions: ["--image", "--target", "--coordinate-contract"],
                    optionalOptions: ["--provider", "--base-url", "--model", "--model-path", "--api-key-env", "--allow-remote-vlm", "--max-tokens", "--temperature", "--seed", "--prompt-template", "--allow-model-download", "--no-model-download", "--output-dir", "--format", "--json"],
                    artifacts: ["vlm-grounding", "vlm-overlay", "vlm-request", "vlm-response", "vlm-raw-output", "vlm-parsed-point", "vlm-transform", "vlm-model-metadata"],
                    nextCommands: [
                        "triton schema --command vlm --json",
                    ],
                    outputSelectors: ["vlm.ground"],
                    failureCodes: [
                        "vlm_unsupported_provider",
                        "vlm_openai_base_url_required",
                        "vlm_openai_base_url_invalid",
                        "vlm_remote_provider_requires_approval",
                        "vlm_api_key_missing",
                        "vlm_provider_request_invalid",
                        "vlm_provider_request_failed",
                        "vlm_provider_response_invalid",
                        "vlm_provider_point_parse_failed",
                        "mlx_model_load_failed",
                        "mlx_generation_failed",
                        "mlx_response_empty",
                        "mlx_parse_failed",
                        "vlm_target_not_visible",
                        "vlm_image_not_found",
                        "vlm_image_metadata_unavailable",
                        "vlm_coordinate_contract_not_found",
                        "vlm_coordinate_contract_invalid",
                        "vlm_coordinate_space_unsupported",
                        "vlm_point_out_of_bounds",
                        "vlm_overlay_failed",
                        "vlm_artifact_write_failed",
                        "vlm_grounding_failed",
                    ]
                ),
                TKCommandSubcommandSchema(
                    name: "providers",
                    summary: "List available VLM grounding providers",
                    requiredOptions: [],
                    optionalOptions: ["--format", "--json"],
                    artifacts: [],
                    nextCommands: [
                        "triton schema --command vlm --json",
                    ],
                    outputSelectors: ["vlm.providers"],
                    failureCodes: []
                ),
            ],
            providedCapabilities: ["vlm-provider-list", "vlm-ground-mock", "vlm-ground-openai-compatible", "vlm-ground-mlx-swift-lm"]
        ),
    ]
}
