import Foundation
import TritonKitShared

let schemaHostPortOptions = [
    TKCommandSchemaOption(name: "--host", type: "String", defaultValue: "127.0.0.1", description: "Triton server host"),
    TKCommandSchemaOption(name: "--port", type: "Int", defaultValue: "19421", description: "Triton server port"),
]

let schemaTargetOption = TKCommandSchemaOption(name: "--target", type: "String", defaultValue: TKLocalTargetID, description: "Target id from `triton list`, or simulator UDID for iOS simulator runtime targets; commands auto-select the only connected target when omitted")
let schemaTargetDeviceAliasOption = TKCommandSchemaOption(name: "--target/--device", type: "String", defaultValue: TKLocalTargetID, description: "Runtime target selector; --device is an alias for --target and accepts target ids, iOS simulator UDIDs, booted, or the only connected target when omitted")
let schemaTextJSONFormats = ["text", "json"]
let schemaFormatTextJSONOption = TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format")
let schemaFormatJSONTextOption = TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format")
let schemaJSONAliasOption = TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --format json")
let schemaLanguageOption = TKCommandSchemaOption(name: "--language/--lang", type: "en|zh", defaultValue: "TRITON_LANGUAGE or en", description: "Human-readable output language")
let schemaRuntimeBaseURLOption = TKCommandSchemaOption(name: "--runtime-base-url", type: "URL", description: "Bypass Triton server and call a direct embedded runtime HTTP base URL, for example \(TKHarmonyRuntimeDefaults.hostAccessBaseURL)")
let schemaMetadataJSONAliasOption = TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --metadata")
let schemaRefreshOption = TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before reading")

let schemaRuntimeTargetFailureCodes = [
    "server_unavailable",
    "target_unavailable",
    "target_not_found",
    "request_failed",
    "runtime_unavailable",
    "runtime_ui_interrupted",
    "request_timeout",
    "invalid_payload",
    "validation_failed",
]

let schemaHierarchyFailureCodes = schemaRuntimeTargetFailureCodes + ["hierarchy_unavailable"]
let schemaNodeFailureCodes = schemaHierarchyFailureCodes + ["node_not_found", "ambiguous_target", "host_command_failed"]
let schemaSemanticActionFailureCodes = schemaRuntimeTargetFailureCodes + [
    "ambiguous_target",
    "text_not_found",
    "semantic_action_failed",
    "action_not_supported",
    "unsupported_runtime_scope",
]

let schemaInputCommandFailureCodes = [
    "unsupported_capability",
    "validation_failed",
    "server_unavailable",
    "target_not_found",
    "ambiguous_target",
    "request_failed",
]

func schemaFields(_ specs: [(String, String, Bool, String)]) -> [TKCommandSchemaField] {
    specs.map { TKCommandSchemaField(name: $0.0, type: $0.1, required: $0.2, description: $0.3) }
}

func inputActionSchemas() -> [TKInputActionSchema] {
    [
        TKInputActionSchema(
            type: "tap",
            requiredFields: ["type"],
            optionalFields: ["x", "y", "targetOID", "matchedOID", "matchedClassName", "activationStrategy", "width", "height", "duration"],
            oneOfRequired: [["x", "y"], ["targetOID"]],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["tap"], "Action discriminator"),
                inputField("x", "Double", "Window x coordinate in points; required with y unless targetOID is used"),
                inputField("y", "Double", "Window y coordinate in points; required with x unless targetOID is used"),
                inputField("targetOID", "UInt", "View oid from hierarchy/ax/hit; alternative to x/y"),
                inputField("matchedOID", "UInt", "Original matched node oid for smart text activation"),
                inputField("matchedClassName", "String", "Original matched node class name for smart text activation"),
                inputField("activationStrategy", "String", enumValues: ["smart", "exact", "ancestor"], "Tap activation strategy"),
                inputField("width", "Double", "Optional window width in points for caller bookkeeping"),
                inputField("height", "Double", "Optional window height in points for caller bookkeeping"),
                inputField("duration", "Double", "Optional hold duration in seconds"),
            ],
            example: #"{"type":"tap","x":270,"y":300}"#
        ),
        TKInputActionSchema(
            type: "swipe",
            requiredFields: ["type", "startX", "startY", "endX", "endY"],
            optionalFields: ["width", "height", "duration"],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["swipe"], "Action discriminator"),
                inputField("startX", "Double", required: true, "Start x coordinate in window points"),
                inputField("startY", "Double", required: true, "Start y coordinate in window points"),
                inputField("endX", "Double", required: true, "End x coordinate in window points"),
                inputField("endY", "Double", required: true, "End y coordinate in window points"),
                inputField("width", "Double", "Optional window width in points for caller bookkeeping"),
                inputField("height", "Double", "Optional window height in points for caller bookkeeping"),
                inputField("duration", "Double", "Optional gesture duration in seconds"),
            ],
            example: #"{"type":"swipe","startX":350,"startY":390,"endX":100,"endY":390}"#
        ),
        TKInputActionSchema(
            type: "type",
            requiredFields: ["type", "text"],
            optionalFields: ["targetOID", "secure"],
            fields: [
                inputField("type", "String", required: true, enumValues: ["type"], "Action discriminator"),
                inputField("text", "String", required: true, "Text to insert into target or first responder"),
                inputField("targetOID", "UInt", "Optional UIKeyInput target oid"),
                inputField("secure", "Bool", "Redact inserted text details in command output"),
            ],
            example: #"{"type":"type","text":"hello"}"#
        ),
        TKInputActionSchema(
            type: "paste",
            requiredFields: ["type", "text"],
            optionalFields: ["targetOID", "x", "y", "secure"],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["paste"], "Action discriminator"),
                inputField("text", "String", required: true, "Exact text to insert into target or first responder"),
                inputField("targetOID", "UInt", "Optional UIKeyInput target oid"),
                inputField("x", "Double", "Window x coordinate to focus before paste; required with y"),
                inputField("y", "Double", "Window y coordinate to focus before paste; required with x"),
                inputField("secure", "Bool", "Redact inserted text details in command output"),
            ],
            example: #"{"type":"paste","text":"console","secure":false}"#,
            resultShape: "{ ok, action, message, targetOID, targetClassName, secure, redacted, insertedLength }"
        ),
        TKInputActionSchema(
            type: "clear",
            requiredFields: ["type"],
            optionalFields: ["targetOID", "x", "y"],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["clear"], "Action discriminator"),
                inputField("targetOID", "UInt", "Optional UIKeyInput target oid"),
                inputField("x", "Double", "Window x coordinate to focus before clear; required with y"),
                inputField("y", "Double", "Window y coordinate to focus before clear; required with x"),
            ],
            example: #"{"type":"clear"}"#,
            resultShape: "{ ok, action, message, targetOID, targetClassName, insertedLength: 0 }"
        ),
        TKInputActionSchema(
            type: "button",
            requiredFields: ["type", "button"],
            optionalFields: ["duration"],
            fields: [
                inputField("type", "String", required: true, enumValues: ["button"], "Action discriminator"),
                inputField("button", "String", required: true, enumValues: ["home"], "Device button name; embedded runtime returns unsupported"),
                inputField("duration", "Double", "Optional press duration in seconds"),
            ],
            example: #"{"type":"button","button":"home"}"#,
            resultShape: "{ ok: false, action, message } in embedded runtime"
        ),
    ]
}

func inputField(
    _ name: String,
    _ type: String,
    required: Bool = false,
    enumValues: [String]? = nil,
    _ description: String
) -> TKInputActionFieldSchema {
    TKInputActionFieldSchema(
        name: name,
        type: type,
        required: required,
        enumValues: enumValues,
        description: description
    )
}

func renderSchema(_ response: TKCLISchemaResponse, language: CLILanguage = effectiveLanguage(nil)) -> String {
    response.commands.map { command in
        var lines = ["\(command.name): \(command.summary)"]
        lines.append("  \(language == .zh ? "需要服务" : "requiresServer"): \(command.requiresServer)")
        lines.append("  \(language == .zh ? "需要目标" : "requiresTarget"): \(command.requiresTarget)")
        lines.append("  \(language == .zh ? "需要层级" : "requiresHierarchy"): \(command.requiresHierarchy)")
        lines.append("  \(language == .zh ? "运行时范围" : "runtimeScope"): \(command.runtimeScope)")
        lines.append("  \(language == .zh ? "失败退出码" : "exitCodeOnFailure"): \(command.exitCodeOnFailure)")
        lines.append("  \(language == .zh ? "输出格式" : "outputFormats"): \(command.outputFormats.joined(separator: ","))")
        if !command.usageForms.isEmpty {
            lines.append("  \(language == .zh ? "用法形态" : "usageForms"):")
            for usageForm in command.usageForms {
                lines.append("    \(usageForm.form): \(usageForm.kind) - \(usageForm.description)")
            }
        }
        if !command.argumentForms.isEmpty {
            lines.append("  \(language == .zh ? "位置参数" : "argumentForms"):")
            for argument in command.argumentForms {
                let required = argument.required ? " required" : ""
                lines.append("    \(argument.name): \(argument.type)\(required) - \(argument.description)")
            }
        }
        if !command.options.isEmpty {
            lines.append("  \(language == .zh ? "选项" : "options"):")
            for option in command.options {
                let required = option.required ? " required" : ""
                let defaultValue = option.defaultValue.map { " default=\($0)" } ?? ""
                lines.append("    \(option.name): \(option.type)\(required)\(defaultValue) - \(option.description)")
            }
        }
        if !command.examples.isEmpty {
            lines.append("  \(language == .zh ? "示例" : "examples"):")
            lines.append(contentsOf: command.examples.map { "    \($0)" })
        }
        if let inputActions = command.inputActions, !inputActions.isEmpty {
            lines.append("  inputActions:")
            for action in inputActions {
                lines.append("    \(action.type): required=\(action.requiredFields.joined(separator: ",")) optional=\(action.optionalFields.joined(separator: ","))")
                if let coordinateSpace = action.coordinateSpace {
                    lines.append("      coordinateSpace: \(coordinateSpace)")
                }
                if !action.oneOfRequired.isEmpty {
                    let oneOf = action.oneOfRequired.map { $0.joined(separator: "+") }.joined(separator: " | ")
                    lines.append("      oneOfRequired: \(oneOf)")
                }
                lines.append("      fields:")
                for field in action.fields {
                    let required = field.required ? " required" : ""
                    let enumValues = field.enumValues.map { " enum=\($0.joined(separator: "|"))" } ?? ""
                    lines.append("        \(field.name): \(field.type)\(required)\(enumValues) - \(field.description)")
                }
                lines.append("      example: \(action.example)")
            }
        }
        return lines.joined(separator: "\n")
    }.joined(separator: "\n\n")
}
