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
                TKCommandSchemaOption(name: "ground", type: "Subcommand", description: "Ground a target phrase using mock or OpenAI-compatible providers"),
                TKCommandSchemaOption(name: "--provider", type: "mock|openai-compatible", defaultValue: "mock", description: "Grounding provider"),
                TKCommandSchemaOption(name: "--image", type: "Path", required: true, description: "Screenshot artifact path"),
                TKCommandSchemaOption(name: "--target", type: "String", required: true, description: "Target phrase to ground"),
                TKCommandSchemaOption(name: "--coordinate-contract", type: "Path", required: true, description: "P0E coordinate-contract.json path"),
                TKCommandSchemaOption(name: "--base-url", type: "URL", description: "OpenAI-compatible /v1 base URL; required for openai-compatible"),
                TKCommandSchemaOption(name: "--model", type: "String", defaultValue: "vlm-grounding", description: "OpenAI-compatible model name"),
                TKCommandSchemaOption(name: "--api-key-env", type: "String", description: "Environment variable containing provider API key"),
                TKCommandSchemaOption(name: "--allow-remote-vlm", type: "Bool", defaultValue: "false", description: "Allow non-localhost VLM provider requests"),
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
            ],
            examples: [
                "triton vlm ground --provider mock --image debug/step-003-after.png --target 'Go Home button' --coordinate-contract coordinate-contract.json --json",
                "triton vlm ground --provider openai-compatible --base-url http://127.0.0.1:8000/v1 --model UGround-V1-7B --image debug/step-003-after.png --target 'Go Home button' --coordinate-contract coordinate-contract.json --json",
            ],
            successShape: "{ ok, provider, target, image, coordinateContract, point{ normalized, runtimePoint, coordinateSpace }, transform, artifacts{ overlay, request, response } }",
            outputSemantics: "offline-only; no network, no API key, no device action; point output is runtime-point derived from coordinate-contract.json",
            artifacts: ["vlm-grounding", "vlm-overlay", "vlm-request", "vlm-response", "coordinate-contract", "screenshot"],
            nextCommands: [
                "triton schema --command vlm --json",
            ],
            outputContracts: [
                vlmGroundOutputContract(),
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
                    summary: "Resolve a target phrase to a runtime-point with mock or OpenAI-compatible VLM grounding",
                    requiredOptions: ["--image", "--target", "--coordinate-contract"],
                    optionalOptions: ["--provider", "--base-url", "--model", "--api-key-env", "--allow-remote-vlm", "--output-dir", "--format", "--json"],
                    artifacts: ["vlm-grounding", "vlm-overlay", "vlm-request", "vlm-response"],
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
            ],
            providedCapabilities: ["vlm-ground-mock", "vlm-ground-openai-compatible"]
        ),
    ]
}
