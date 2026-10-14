import Foundation

public struct TKCommandSchemaOption: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let defaultValue: String?
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = false,
        defaultValue: String? = nil,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.defaultValue = defaultValue
        self.description = description
    }
}

public struct TKCommandUsageForm: Codable, Equatable {
    public let form: String
    public let kind: String
    public let description: String

    public init(
        form: String,
        kind: String,
        description: String
    ) {
        self.form = form
        self.kind = kind
        self.description = description
    }
}

public struct TKCommandArgumentForm: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = false,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
    }
}

public struct TKCommandSchemaField: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = true,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
    }
}

public struct TKCommandOutputContract: Codable, Equatable {
    public let selector: String
    public let format: String
    public let kind: String
    public let model: String?
    public let fields: [TKCommandSchemaField]

    public init(
        selector: String,
        format: String,
        kind: String,
        model: String? = nil,
        fields: [TKCommandSchemaField]
    ) {
        self.selector = selector
        self.format = format
        self.kind = kind
        self.model = model
        self.fields = fields
    }
}

public struct TKCommandRecoveryCommand: Codable, Equatable {
    public let command: String
    public let category: String

    public init(command: String, category: String) {
        self.command = command
        self.category = category
    }

    public init?(commandString: String) {
        guard let root = Self.rootCommand(in: commandString),
              let category = Self.category(forRootCommand: root) else {
            return nil
        }
        self.init(command: commandString, category: category)
    }

    public static func rootCommand(in commandString: String) -> String? {
        let tokens = commandString.split(separator: " ").map(String.init)
        guard let tritonIndex = tokens.firstIndex(of: "triton"), tokens.count > tritonIndex + 1 else {
            return nil
        }
        return tokens[tritonIndex + 1]
    }

    public static func category(forRootCommand rootCommand: String) -> String? {
        recoveryCommandRootCategoryMap[rootCommand]
    }

    public static var categoryTaxonomy: Set<String> {
        [
            "act",
            "archive",
            "diagnose",
            "discover",
            "observe",
            "plan",
            "prepare-target",
            "project",
            "replay",
            "smoke",
            "verify",
        ]
    }

    public static var rootCommandTaxonomy: Set<String> {
        Set(recoveryCommandRootCategoryMap.keys)
    }

    /// Specific resident XCTest failure families. Unknown codes remain unclassified.
    /// Delivered or uncertain actions recover through observation and receipts, never automatic replay.
    public static func residentRunnerRecoveryCategories(forFailureCode failureCode: String) -> [String]? {
        switch failureCode {
        case "ios_runner_transport_unknown", "ios_runner_stop_unknown", "outcome_unknown", "unauthorized", "ios_runner_invalid_response", "extra_bytes", "request_complete", "ios_runner_internal", "ios_runner_operation_failed", "ios_runner_command_timeout", "listener_failed":
            return ["diagnose", "observe", "archive", "plan"]
        case "ios_runner_already_running", "ios_runner_busy", "ios_runner_owner_unknown", "ios_runner_owner_missing", "ios_runner_session_not_ready", "ios_runner_start_not_ready", "ios_runner_session_missing", "ios_runner_session_target_mismatch", "ios_runner_prepare_required", "ios_runner_lock_failed", "session_stopping", "fixture_not_foreground":
            return ["diagnose", "prepare-target", "plan"]
        case "cross_app_activation", "cross_app_address", "cross_app_ambiguous", "cross_app_binding", "cross_app_direction", "cross_app_focus", "cross_app_limit", "cross_app_navigation", "cross_app_not_foreground", "cross_app_not_hittable", "cross_app_operation", "cross_app_selector", "cross_app_text", "cross_app_unobserved", "ios_runner_bundle_not_allowed":
            return ["diagnose", "observe", "plan"]
        case "ios_runner_action_request_id_required", "ios_runner_build_artifact_ambiguous", "ios_runner_build_failed", "ios_runner_entropy_failed", "ios_runner_explicit_device_required", "ios_runner_identity_unavailable", "ios_runner_invalid_allow_bundles", "ios_runner_invalid_operation", "ios_runner_invalid_payload", "ios_runner_invalid_request_id", "ios_runner_invalid_route", "ios_runner_invalid_team", "ios_runner_invalid_timeout", "ios_runner_invalid_ttl", "ios_runner_resource_invalid", "ios_runner_resource_missing", "ios_runner_team_required", "ios_runner_test_configuration_invalid", "ios_runner_unsafe_store", "ios_runner_unsupported_target":
            return ["diagnose", "project", "plan"]
        case "ios_runner_artifact_exists", "ios_runner_artifact_unwritable", "ios_runner_body_too_large", "ios_runner_payload_too_large", "ios_runner_receipt_image_unverified", "ios_runner_receipt_save_failed", "ios_runner_screenshot_export_failed", "ios_runner_store_failed", "receipt_budget", "receipt_byte_budget", "receipt_size_budget", "screenshot_budget", "screenshot_dimension_budget", "screenshot_invalid", "ui_queue_budget":
            return ["diagnose", "archive", "plan"]
        default: return nil
        }
    }

    public static func recoveryCategories(forFailureCode failureCode: String) -> [String] {
        // Highlight recovery observes an existing operation/session before replanning.
        // It never suggests installing a provider, forcing restore, or replaying apply.
        switch failureCode {
        case "highlight_unsupported", "highlight_busy", "highlight_operation_conflict", "highlight_capacity_exceeded", "highlight_receipt_expired":
            return ["diagnose", "plan"]
        case "highlight_target_ambiguous", "highlight_target_not_found", "highlight_identity_unverifiable", "highlight_identity_changed", "highlight_stale_runtime":
            return ["diagnose", "observe", "plan"]
        case "highlight_render_timeout", "highlight_restore_conflict", "highlight_restore_failed":
            return ["diagnose", "observe"]
        default: break
        }
        if let categories = residentRunnerRecoveryCategories(forFailureCode: failureCode) { return categories }
        if ["screenshot_deadline_exceeded", "insufficient_visual_samples", "visual_motion_timeout", "runtime_ui_timeout", "runtime_ui_busy", "runtime_ui_circuit_open"].contains(failureCode) {
            return ["diagnose", "observe", "plan"]
        }
        // Runner failures may follow delivered input. Inspect evidence before replanning; never suggest replay.
        if failureCode.hasPrefix("runner_") || failureCode.hasPrefix("invalid_runner_") || failureCode == "unsupported_runner_action" {
            return ["diagnose", "plan"]
        }
        var categories: [String] = []
        if targetFailureCodesRequiringRecovery.contains(failureCode) {
            categories.append("prepare-target")
        }
        if projectFailureCodesRequiringRecovery.contains(failureCode) {
            categories.append("project")
        }
        if actionFailureCodesRequiringRecovery.contains(failureCode) {
            categories.append("act")
        }
        if failureCode == "proxy_real_device_not_supported" {
            categories.append("diagnose")
        }
        if destructivePolicyFailureCodesRequiringRecovery.contains(failureCode) || unsupportedFailureCodesRequiringRecovery.contains(failureCode) || failureCode == "proxy_cert_untrusted" {
            categories.append("plan")
        }
        if failureCode == "timeout" {
            categories.append("verify")
        }
        if ["collection_cell_selection_blocked", "collection_cell_selection_denied"].contains(failureCode) {
            categories.append("diagnose")
        }
        if ["device_files_limit_exceeded", "device_mountpoint_limit_exceeded", "device_mount_execution_uncertain", "device_fs_limit_exceeded", "device_fs_unsafe_root", "device_fs_directory_unavailable", "device_file_domain_execution_uncertain", "device_administration_policy_required", "device_administration_result_invalid", "device_administration_identity_mismatch", "device_administration_unsafe_artifact", "device_administration_limit_exceeded", "device_administration_audit_failed", "device_administration_failed", "device_administration_timeout", "device_administration_postcondition_unverified", "unsupported_device_administration", "app_container_unsupported_platform", "app_container_unsupported_sdk", "app_container_unsupported_listing", "app_container_query_failed", "app_container_timeout", "app_container_json_missing", "app_container_invalid_json", "app_container_identity_mismatch", "app_container_unavailable", "app_container_root_mismatch", "app_container_unsafe_root", "app_container_read_failed", "app_container_limit_exceeded", "sim_pairs_query_failed"].contains(failureCode) {
            categories.append(contentsOf: ["diagnose", "plan"])
        }
        if failureCode == "stale_node_alias" {
            categories.append(contentsOf: ["diagnose", "observe", "plan"])
        }
        if ["request_failed", "server_unavailable", "target_unavailable", "runtime_unavailable", "proxy_status_probe_failed"].contains(failureCode) {
            categories.append("diagnose")
        }
        if ["artifact_write_failed", "file_write_failed", "artifact_output_rejected"].contains(failureCode) {
            categories.append("archive")
        }
        if ["output_already_exists", "output_write_failed"].contains(failureCode) {
            categories.append(contentsOf: ["archive", "diagnose"])
        }
        if ["sim_record_truncated", "sim_record_invalid_artifact"].contains(failureCode) {
            categories.append(contentsOf: ["archive", "diagnose"])
        }
        if ["host_screenshot_unavailable", "evidence_capture_partial"].contains(failureCode) {
            categories.append(contentsOf: ["archive", "diagnose"])
        }
        if failureCode == "app_map_error" || failureCode == "unconfirmed_path" || failureCode == "non_replayable_path" {
            categories.append(contentsOf: ["archive", "plan"])
        }
        if ["contract_quality_review_required", "redaction_review_required", "source_identity_mismatch", "truncated_source_contract", "unmapped_contract_feature", "compiled_digest_mismatch"].contains(failureCode) {
            categories.append(contentsOf: ["diagnose", "plan"])
        }
        // Receipt-backed reliability collection failures deliberately recover
        // through inspection only. A reservation/slot conflict or a runner
        // failure must never suggest cleanup, force-overwrite, or another
        // runtime execution against the same private evidence root.
        if [
            "invalid_reliability_collection",
            "invalid_reliability_receipt",
            "invalid_reliability_receipt_anchor",
            "reliability_receipt_anchor_mismatch",
            "reliability_sample_confirmation_required",
            "invalid_reliability_sample_request",
            "invalid_reliability_reset_receipt",
            "reliability_reservation_exists",
            "reliability_collection_busy",
            "reliability_slot_already_claimed",
        ].contains(failureCode) {
            categories.append("diagnose")
        }
        if [
            "reliability_reservation_write_failed",
            "test_reliability_sample_failed",
            "reliability_identity_chain_write_failed",
        ].contains(failureCode) {
            categories.append(contentsOf: ["diagnose", "archive"])
        }
        if failureCode.hasPrefix("ai_") {
            categories.append(contentsOf: ["archive", "diagnose", "plan"])
        }
        return categories
    }

    private static let recoveryCommandRootCategoryMap: [String: String] = [
        "act": "act",
        "action": "act",
        "app": "prepare-target",
        "assert": "verify",
        "attrs": "observe",
        "ax": "observe",
        "capabilities": "diagnose",
        "capture": "archive",
        "clear": "act",
        "coverage": "archive",
        "debug": "diagnose",
        "device": "prepare-target",
        "doctor": "diagnose",
        "evidence": "archive",
        "export": "archive",
        "find": "discover",
        "focus": "act",
        "geometry": "observe",
        "hierarchy": "observe",
        "highlight": "diagnose",
        "hit": "observe",
        "input": "act",
        "inspect": "discover",
        "ledger": "archive",
        "list": "discover",
        "map": "archive",
        "node": "observe",
        "nodes": "observe",
        "object": "observe",
        "observe": "observe",
        "paste": "act",
        "plan": "plan",
        "press": "act",
        "record": "replay",
        "replay": "replay",
        "route": "verify",
        "runtime": "diagnose",
        "schema": "diagnose",
        "screenshot": "archive",
        "select-segment": "act",
        "serve": "diagnose",
        "set-switch": "act",
        "set-text": "act",
        "sim": "prepare-target",
        "smoke": "smoke",
        "snapshot": "observe",
        "state": "observe",
        "status": "diagnose",
        "swipe": "act",
        "tap": "act",
        "target": "prepare-target",
        "test": "diagnose",
        "testrec": "diagnose",
        "type": "act",
        "update": "diagnose",
        "version": "diagnose",
        "verify": "verify",
        "vlm": "archive",
        "wait": "verify",
        "web": "observe",
        "webview": "observe",
        "xcode": "project",
        "xcresult": "archive",
        "xctrace": "archive",
    ]

    private static let targetFailureCodesRequiringRecovery: Set<String> = [
        "ambiguous_target",
        "device_not_ready",
        "simulator_not_found",
        "target_not_found",
        "target_offline",
        "target_unavailable",
        "proxy_real_device_not_supported",
    ]

    private static let projectFailureCodesRequiringRecovery: Set<String> = [
        "ambiguous_workspace",
        "invalid_workspace_path",
        "scheme_not_found",
        "workspace_not_found",
        "xcode_not_idle",
        "xcode_schemes_timeout",
        "xcodebuild_interrupted",
        "orphaned_xcodebuild",
    ]

    private static let actionFailureCodesRequiringRecovery: Set<String> = [
        "action_failed",
        "step_failed",
    ]

    private static let destructivePolicyFailureCodesRequiringRecovery: Set<String> = [
        "confirmation_required",
        "destructive_action_requires_policy",
        "device_mount_execution_uncertain",
    ]

    private static let unsupportedFailureCodesRequiringRecovery: Set<String> = [
        "action_not_supported",
        "contract_quality_review_required",
        "redaction_review_required",
        "unmapped_contract_feature",
        "unsupported_compiled_contract",
        "unsupported_host_action",
        "unsupported_import_platform",
        "unsupported_capability",
        "unsupported_runtime_scope",
        "proxy_real_device_not_supported",
        "webview_method_not_allowed",
        "webview_wait_unsupported",
    ]
}

public struct TKCommandSubcommandSchema: Codable, Equatable {
    public let name: String
    public let summary: String
    /// Subcommand-specific runtime requirements. Defaults preserve older schema snapshots.
    public let requiresServer: Bool
    public let requiresTarget: Bool
    public let requiresConfirmation: Bool
    public let sideEffect: String
    /// Overrides for an option whose semantics differ from the root command.
    public let optionOverrides: [TKCommandSchemaOption]
    public let requiredOptions: [String]
    public let oneOfRequiredOptions: [[String]]
    /// Complete alternative option sets. Exactly one set applies and every option in it is required.
    /// This is additive so legacy oneOfRequiredOptions consumers retain their existing semantics.
    public let oneOfRequiredOptionSets: [[String]]
    public let optionalOptions: [String]
    public let defaultProviders: [String]
    public let inheritsDefaultsFrom: [String]
    public let jsonlEvents: [String]
    public let finalEventKind: String?
    public let artifacts: [String]
    public let retryable: Bool
    public let nextCommands: [String]
    public let recoveryCommands: [TKCommandRecoveryCommand]
    public let outputSelectors: [String]
    public let failureCodes: [String]
    public let subcommands: [TKCommandSubcommandSchema]

    enum CodingKeys: String, CodingKey {
        case name
        case summary
        case requiresServer
        case requiresTarget
        case requiresConfirmation
        case sideEffect
        case optionOverrides
        case requiredOptions
        case oneOfRequiredOptions
        case oneOfRequiredOptionSets
        case optionalOptions
        case defaultProviders
        case inheritsDefaultsFrom
        case jsonlEvents
        case finalEventKind
        case artifacts
        case retryable
        case nextCommands
        case recoveryCommands
        case outputSelectors
        case failureCodes
        case subcommands
    }

    public init(
        name: String,
        summary: String,
        requiresServer: Bool = false,
        requiresTarget: Bool = false,
        requiresConfirmation: Bool = false,
        sideEffect: String = "none",
        optionOverrides: [TKCommandSchemaOption] = [],
        requiredOptions: [String] = [],
        oneOfRequiredOptions: [[String]] = [],
        oneOfRequiredOptionSets: [[String]] = [],
        optionalOptions: [String] = [],
        defaultProviders: [String] = [],
        inheritsDefaultsFrom: [String] = [],
        jsonlEvents: [String] = [],
        finalEventKind: String? = nil,
        artifacts: [String] = [],
        retryable: Bool = false,
        nextCommands: [String] = [],
        recoveryCommands: [TKCommandRecoveryCommand] = [],
        outputSelectors: [String] = [],
        failureCodes: [String] = [],
        subcommands: [TKCommandSubcommandSchema] = []
    ) {
        self.name = name
        self.summary = summary
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.requiresConfirmation = requiresConfirmation
        self.sideEffect = sideEffect
        self.optionOverrides = optionOverrides
        self.requiredOptions = requiredOptions
        self.oneOfRequiredOptions = oneOfRequiredOptions
        self.oneOfRequiredOptionSets = oneOfRequiredOptionSets
        self.optionalOptions = optionalOptions
        self.defaultProviders = defaultProviders
        self.inheritsDefaultsFrom = inheritsDefaultsFrom
        self.jsonlEvents = jsonlEvents
        self.finalEventKind = finalEventKind
        self.artifacts = artifacts
        self.retryable = retryable
        self.nextCommands = nextCommands
        self.recoveryCommands = recoveryCommands.isEmpty ?
            nextCommands.compactMap(TKCommandRecoveryCommand.init(commandString:)) :
            recoveryCommands
        self.outputSelectors = outputSelectors
        self.failureCodes = failureCodes
        self.subcommands = subcommands
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            summary: try container.decode(String.self, forKey: .summary),
            requiresServer: try container.decodeIfPresent(Bool.self, forKey: .requiresServer) ?? false,
            requiresTarget: try container.decodeIfPresent(Bool.self, forKey: .requiresTarget) ?? false,
            requiresConfirmation: try container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation) ?? false,
            sideEffect: try container.decodeIfPresent(String.self, forKey: .sideEffect) ?? "none",
            optionOverrides: try container.decodeIfPresent([TKCommandSchemaOption].self, forKey: .optionOverrides) ?? [],
            requiredOptions: try container.decodeIfPresent([String].self, forKey: .requiredOptions) ?? [],
            oneOfRequiredOptions: try container.decodeIfPresent([[String]].self, forKey: .oneOfRequiredOptions) ?? [],
            oneOfRequiredOptionSets: try container.decodeIfPresent([[String]].self, forKey: .oneOfRequiredOptionSets) ?? [],
            optionalOptions: try container.decodeIfPresent([String].self, forKey: .optionalOptions) ?? [],
            defaultProviders: try container.decodeIfPresent([String].self, forKey: .defaultProviders) ?? [],
            inheritsDefaultsFrom: try container.decodeIfPresent([String].self, forKey: .inheritsDefaultsFrom) ?? [],
            jsonlEvents: try container.decodeIfPresent([String].self, forKey: .jsonlEvents) ?? [],
            finalEventKind: try container.decodeIfPresent(String.self, forKey: .finalEventKind),
            artifacts: try container.decodeIfPresent([String].self, forKey: .artifacts) ?? [],
            retryable: try container.decodeIfPresent(Bool.self, forKey: .retryable) ?? false,
            nextCommands: try container.decodeIfPresent([String].self, forKey: .nextCommands) ?? [],
            recoveryCommands: try container.decodeIfPresent([TKCommandRecoveryCommand].self, forKey: .recoveryCommands) ?? [],
            outputSelectors: try container.decodeIfPresent([String].self, forKey: .outputSelectors) ?? [],
            failureCodes: try container.decodeIfPresent([String].self, forKey: .failureCodes) ?? [],
             subcommands: try container.decodeIfPresent([TKCommandSubcommandSchema].self, forKey: .subcommands) ?? []
        )
    }
}

public struct TKCommandSchema: Codable, Equatable {
    private static let defaultFailureShape = "{ ok: false, error: { code, message, endpoint, hint, nextAction?{ command,args,category,requiresLongRunningProcess?,readyEvents,finalEvents,terminationSignals } } }"

    public let name: String
    public let summary: String
    public let requiresServer: Bool
    public let requiresTarget: Bool
    public let requiresHierarchy: Bool
    public let runtimeScope: String
    public let exitCodeOnFailure: Int
    public let outputFormats: [String]
    public let options: [TKCommandSchemaOption]
    public let usageForms: [TKCommandUsageForm]
    public let argumentForms: [TKCommandArgumentForm]
    public let examples: [String]
    public let successShape: String?
    public let failureShape: String?
    public let outputSemantics: String?
    public let requiredOptions: [String]
    public let inheritsDefaultsFrom: [String]
    public let jsonlEvents: [String]
    public let finalEventKind: String?
    public let artifacts: [String]
    public let retryable: Bool
    public let nextCommands: [String]
    public let recoveryCommands: [TKCommandRecoveryCommand]
    public let outputContracts: [TKCommandOutputContract]
    public let failureCodes: [String]
    public let subcommands: [TKCommandSubcommandSchema]
    public let inputActions: [TKInputActionSchema]?
    public let providedCapabilities: [String]
    public let surfaceLayer: String
    public let deprecatedForMainPath: Bool
    public let replacementCommand: String?
    public let rawDebugCommand: String?
    public let surfaceRationale: String?

    enum CodingKeys: String, CodingKey {
        case name
        case summary
        case requiresServer
        case requiresTarget
        case requiresHierarchy
        case runtimeScope
        case exitCodeOnFailure
        case outputFormats
        case options
        case usageForms
        case argumentForms
        case examples
        case successShape
        case failureShape
        case outputSemantics
        case requiredOptions
        case inheritsDefaultsFrom
        case jsonlEvents
        case finalEventKind
        case artifacts
        case retryable
        case nextCommands
        case recoveryCommands
        case outputContracts
        case failureCodes
        case subcommands
        case inputActions
        case providedCapabilities
        case surfaceLayer
        case deprecatedForMainPath
        case replacementCommand
        case rawDebugCommand
        case surfaceRationale
    }

    public init(
        name: String,
        summary: String,
        requiresServer: Bool,
        requiresTarget: Bool,
        requiresHierarchy: Bool = false,
        runtimeScope: String = "cli",
        exitCodeOnFailure: Int = 1,
        outputFormats: [String],
        options: [TKCommandSchemaOption],
        usageForms: [TKCommandUsageForm] = [],
        argumentForms: [TKCommandArgumentForm] = [],
        examples: [String],
        successShape: String? = nil,
        failureShape: String? = "{ ok: false, error: { code, message, endpoint, hint, nextAction?{ command,args,category,requiresLongRunningProcess?,readyEvents,finalEvents,terminationSignals } } }",
        outputSemantics: String? = nil,
        requiredOptions: [String] = [],
        inheritsDefaultsFrom: [String] = [],
        jsonlEvents: [String] = [],
        finalEventKind: String? = nil,
        artifacts: [String] = [],
        retryable: Bool = false,
        nextCommands: [String] = [],
        recoveryCommands: [TKCommandRecoveryCommand] = [],
        outputContracts: [TKCommandOutputContract] = [],
        failureCodes: [String] = [],
        subcommands: [TKCommandSubcommandSchema] = [],
        inputActions: [TKInputActionSchema]? = nil,
        providedCapabilities: [String] = [],
        surfaceLayer: String = "workflow",
        deprecatedForMainPath: Bool = false,
        replacementCommand: String? = nil,
        rawDebugCommand: String? = nil,
        surfaceRationale: String? = nil
    ) {
        self.name = name
        self.summary = summary
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.requiresHierarchy = requiresHierarchy
        self.runtimeScope = runtimeScope
        self.exitCodeOnFailure = exitCodeOnFailure
        self.outputFormats = outputFormats
        self.options = options.filter { !$0.isUsageFormSeed && !$0.isArgumentFormSeed }
        self.usageForms = usageForms + options.compactMap(\.usageFormSeed)
        self.argumentForms = argumentForms + options.compactMap(\.argumentFormSeed)
        self.examples = examples
        self.successShape = successShape
        self.failureShape = TKCommandSchema.normalizedFailureShape(failureShape)
        self.outputSemantics = outputSemantics
        self.requiredOptions = requiredOptions
        self.inheritsDefaultsFrom = inheritsDefaultsFrom
        self.jsonlEvents = jsonlEvents
        self.finalEventKind = finalEventKind
        self.artifacts = artifacts
        self.retryable = retryable
        self.nextCommands = nextCommands
        self.recoveryCommands = recoveryCommands.isEmpty ?
            nextCommands.compactMap(TKCommandRecoveryCommand.init(commandString:)) :
            recoveryCommands
        self.outputContracts = outputContracts
        self.failureCodes = failureCodes
        self.subcommands = subcommands
        self.inputActions = inputActions
        self.providedCapabilities = providedCapabilities
        self.surfaceLayer = surfaceLayer
        self.deprecatedForMainPath = deprecatedForMainPath
        self.replacementCommand = replacementCommand
        self.rawDebugCommand = rawDebugCommand
        self.surfaceRationale = surfaceRationale
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            summary: try container.decode(String.self, forKey: .summary),
            requiresServer: try container.decode(Bool.self, forKey: .requiresServer),
            requiresTarget: try container.decode(Bool.self, forKey: .requiresTarget),
            requiresHierarchy: try container.decodeIfPresent(Bool.self, forKey: .requiresHierarchy) ?? false,
            runtimeScope: try container.decodeIfPresent(String.self, forKey: .runtimeScope) ?? "cli",
            exitCodeOnFailure: try container.decodeIfPresent(Int.self, forKey: .exitCodeOnFailure) ?? 1,
            outputFormats: try container.decode([String].self, forKey: .outputFormats),
            options: try container.decode([TKCommandSchemaOption].self, forKey: .options),
            usageForms: try container.decodeIfPresent([TKCommandUsageForm].self, forKey: .usageForms) ?? [],
            argumentForms: try container.decodeIfPresent([TKCommandArgumentForm].self, forKey: .argumentForms) ?? [],
            examples: try container.decode([String].self, forKey: .examples),
            successShape: try container.decodeIfPresent(String.self, forKey: .successShape),
            failureShape: try container.decodeIfPresent(String.self, forKey: .failureShape) ?? TKCommandSchema.defaultFailureShape,
            outputSemantics: try container.decodeIfPresent(String.self, forKey: .outputSemantics),
            requiredOptions: try container.decodeIfPresent([String].self, forKey: .requiredOptions) ?? [],
            inheritsDefaultsFrom: try container.decodeIfPresent([String].self, forKey: .inheritsDefaultsFrom) ?? [],
            jsonlEvents: try container.decodeIfPresent([String].self, forKey: .jsonlEvents) ?? [],
            finalEventKind: try container.decodeIfPresent(String.self, forKey: .finalEventKind),
            artifacts: try container.decodeIfPresent([String].self, forKey: .artifacts) ?? [],
            retryable: try container.decodeIfPresent(Bool.self, forKey: .retryable) ?? false,
            nextCommands: try container.decodeIfPresent([String].self, forKey: .nextCommands) ?? [],
            recoveryCommands: try container.decodeIfPresent([TKCommandRecoveryCommand].self, forKey: .recoveryCommands) ?? [],
            outputContracts: try container.decodeIfPresent([TKCommandOutputContract].self, forKey: .outputContracts) ?? [],
            failureCodes: try container.decodeIfPresent([String].self, forKey: .failureCodes) ?? [],

            subcommands: try container.decodeIfPresent([TKCommandSubcommandSchema].self, forKey: .subcommands) ?? [],
            inputActions: try container.decodeIfPresent([TKInputActionSchema].self, forKey: .inputActions),
            providedCapabilities: try container.decodeIfPresent([String].self, forKey: .providedCapabilities) ?? [],
            surfaceLayer: try container.decodeIfPresent(String.self, forKey: .surfaceLayer) ?? "workflow",
            deprecatedForMainPath: try container.decodeIfPresent(Bool.self, forKey: .deprecatedForMainPath) ?? false,
            replacementCommand: try container.decodeIfPresent(String.self, forKey: .replacementCommand),
            rawDebugCommand: try container.decodeIfPresent(String.self, forKey: .rawDebugCommand),
            surfaceRationale: try container.decodeIfPresent(String.self, forKey: .surfaceRationale)
        )
    }

    private static func normalizedFailureShape(_ failureShape: String?) -> String? {
        guard let failureShape else {
            return nil
        }
        let nextActionLifecycleShape = "nextAction?{ command,args,category,requiresLongRunningProcess?,readyEvents,finalEvents,terminationSignals }"
        let legacyNextActionShape = "nextAction?{ command,args,category,requiresLongRunningProcess? }"
        if failureShape.contains(legacyNextActionShape) {
            return failureShape.replacingOccurrences(
                of: legacyNextActionShape,
                with: nextActionLifecycleShape
            )
        }
        guard failureShape.contains("nextAction?"),
              !failureShape.contains("nextAction.category"),
              !failureShape.contains("nextAction?{")
        else {
            return failureShape
        }
        return failureShape.replacingOccurrences(
            of: "nextAction?",
            with: nextActionLifecycleShape
        )
    }
}

private extension TKCommandSchemaOption {
    var isUsageFormSeed: Bool {
        usageFormSeed != nil
    }

    var isArgumentFormSeed: Bool {
        argumentFormSeed != nil
    }

    var argumentFormSeed: TKCommandArgumentForm? {
        guard name.hasPrefix("<"), name.hasSuffix(">") else {
            return nil
        }
        return TKCommandArgumentForm(
            name: name,
            type: type,
            required: required,
            description: description
        )
    }

    var usageFormSeed: TKCommandUsageForm? {
        switch type {
        case "Subcommand", "Task":
            return TKCommandUsageForm(form: name, kind: type, description: description)
        default:
            return nil
        }
    }
}

public struct TKHTTPManagementEndpointSchema: Codable, Equatable {
    public let method: String
    public let path: String
    public let successShape: String
    public let failureShape: String

    public init(
        method: String,
        path: String,
        successShape: String,
        failureShape: String = "{ ok: false, error: { code, message, endpoint, hint } }"
    ) {
        self.method = method
        self.path = path
        self.successShape = successShape
        self.failureShape = failureShape
    }
}

public struct TKInputActionSchema: Codable, Equatable {
    public let type: String
    public let requiredFields: [String]
    public let optionalFields: [String]
    public let oneOfRequired: [[String]]
    public let coordinateSpace: String?
    public let fields: [TKInputActionFieldSchema]
    public let example: String
    public let resultShape: String

    public init(
        type: String,
        requiredFields: [String],
        optionalFields: [String],
        oneOfRequired: [[String]] = [],
        coordinateSpace: String? = nil,
        fields: [TKInputActionFieldSchema],
        example: String,
        resultShape: String = "{ ok, action, message, targetOID, targetClassName }"
    ) {
        self.type = type
        self.requiredFields = requiredFields
        self.optionalFields = optionalFields
        self.oneOfRequired = oneOfRequired
        self.coordinateSpace = coordinateSpace
        self.fields = fields
        self.example = example
        self.resultShape = resultShape
    }
}

public struct TKInputActionFieldSchema: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let enumValues: [String]?
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = false,
        enumValues: [String]? = nil,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.enumValues = enumValues
        self.description = description
    }
}

public struct TKCLISchemaResponse: Codable, Equatable {
    public let schemaVersion: Int
    public let commands: [TKCommandSchema]
    public let httpManagementAPI: [TKHTTPManagementEndpointSchema]

    public init(
        schemaVersion: Int = 1,
        commands: [TKCommandSchema],
        httpManagementAPI: [TKHTTPManagementEndpointSchema] = []
    ) {
        self.schemaVersion = schemaVersion
        self.commands = commands
        self.httpManagementAPI = httpManagementAPI
    }
}
