import Foundation

public enum TKReplayAction: String, Codable, CaseIterable {
    case tap
    case paste
    case type
    case clear
    case wait
    case screenshot
    case evidence
    case proxyProbe = "proxy-probe"
    case proxyServe = "proxy-serve"
    case proxyStart = "proxy-start"
    case proxyStatus = "proxy-status"
    case proxyExport = "proxy-export"
    case proxyStop = "proxy-stop"
}

public enum TKReplayWaitCondition: String, Codable, Equatable {
    case text
    case gone
    case exists
    case idle
    case predicate
    case hierarchyChange = "hierarchy-change"
}

public struct TKReplayPlan: Codable, Equatable {
    public let schemaVersion: Int
    public let name: String?
    public let variables: [String]
    public let target: TKReplayPlanTarget?
    public let steps: [TKReplayPlanStep]

    public init(
        schemaVersion: Int = 1,
        name: String? = nil,
        variables: [String] = [],
        target: TKReplayPlanTarget? = nil,
        steps: [TKReplayPlanStep]
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.variables = variables
        self.target = target
        self.steps = steps
    }

    public static func template(name: String = "smoke-flow") -> TKReplayPlan {
        TKReplayPlan(
            name: name,
            variables: ["username", "password"],
            target: TKReplayPlanTarget(id: TKLocalTargetID),
            steps: [
                TKReplayPlanStep(action: .tap, text: "登录"),
                TKReplayPlanStep(action: .tap, x: 180, y: 250),
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .tap, x: 180, y: 304),
                TKReplayPlanStep(action: .paste, value: "${password}", secure: true),
                TKReplayPlanStep(action: .tap, x: 201, y: 459),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )
    }
}

public struct TKReplayPlanTarget: Codable, Equatable {
    public let id: String?
    public let appName: String?
    public let bundleIdentifier: String?
    public let deviceDescription: String?
    public let osDescription: String?

    public init(
        id: String? = nil,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        deviceDescription: String? = nil,
        osDescription: String? = nil
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.deviceDescription = deviceDescription
        self.osDescription = osDescription
    }
}

public struct TKReplayPlanStep: Codable, Equatable {
    public let action: TKReplayAction
    public let id: String?
    public let name: String?
    public let text: String?
    public let gone: String?
    public let exists: String?
    public let idle: Bool?
    public let hierarchyChange: Bool?
    public let predicate: String?
    public let role: String?
    public let value: String?
    public let secure: Bool?
    public let x: Double?
    public let y: Double?
    public let oid: UInt?
    public let axOID: UInt?
    public let axLabel: String?
    public let width: Double?
    public let height: Double?
    public let duration: Double?
    public let timeout: Double?
    public let interval: Double?
    public let output: String?
    public let include: String?
    public let proxySession: String?
    public let platform: String?
    public let device: String?
    public let proxy: String?
    public let mode: String?
    public let restore: Bool?
    public let note: String?
    public let refresh: Bool?

    public init(
        action: TKReplayAction,
        id: String? = nil,
        name: String? = nil,
        text: String? = nil,
        gone: String? = nil,
        exists: String? = nil,
        idle: Bool? = nil,
        hierarchyChange: Bool? = nil,
        predicate: String? = nil,
        role: String? = nil,
        value: String? = nil,
        secure: Bool? = nil,
        x: Double? = nil,
        y: Double? = nil,
        oid: UInt? = nil,
        axOID: UInt? = nil,
        axLabel: String? = nil,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        timeout: Double? = nil,
        interval: Double? = nil,
        output: String? = nil,
        include: String? = nil,
        proxySession: String? = nil,
        platform: String? = nil,
        device: String? = nil,
        proxy: String? = nil,
        mode: String? = nil,
        restore: Bool? = nil,
        note: String? = nil,
        refresh: Bool? = nil
    ) {
        self.action = action
        self.id = id
        self.name = name
        self.text = text
        self.gone = gone
        self.exists = exists
        self.idle = idle
        self.hierarchyChange = hierarchyChange
        self.predicate = predicate
        self.role = role
        self.value = value
        self.secure = secure
        self.x = x
        self.y = y
        self.oid = oid
        self.axOID = axOID
        self.axLabel = axLabel
        self.width = width
        self.height = height
        self.duration = duration
        self.timeout = timeout
        self.interval = interval
        self.output = output
        self.include = include
        self.proxySession = proxySession
        self.platform = platform
        self.device = device
        self.proxy = proxy
        self.mode = mode
        self.restore = restore
        self.note = note
        self.refresh = refresh
    }

    public var waitCondition: TKReplayWaitCondition? {
        guard action == .wait else { return nil }
        if text != nil { return .text }
        if gone != nil { return .gone }
        if exists != nil { return .exists }
        if idle == true { return .idle }
        if hierarchyChange == true { return .hierarchyChange }
        if predicate != nil { return .predicate }
        return nil
    }

    public func redactedValue(substitutedValue: String) -> String {
        if secure == true {
            return "<redacted:\(substitutedValue.count)>"
        }
        return substitutedValue
    }
}

public struct TKRecordPlanResponse: Codable, Equatable {
    public let ok: Bool
    public let output: String
    public let templateOnly: Bool
    public let message: String
    public let plan: TKReplayPlan

    public init(
        ok: Bool,
        output: String,
        templateOnly: Bool,
        message: String,
        plan: TKReplayPlan
    ) {
        self.ok = ok
        self.output = output
        self.templateOnly = templateOnly
        self.message = message
        self.plan = plan
    }
}

public struct TKReplayPlanSummary: Codable, Equatable {
    public let ok: Bool
    public let path: String
    public let schemaVersion: Int
    public let name: String?
    public let variables: [String]
    public let stepCount: Int
    public let actions: [String]
    public let target: TKReplayPlanTarget?
    public let steps: [TKReplayPlanStepSummary]

    public init(ok: Bool, path: String, plan: TKReplayPlan) {
        self.ok = ok
        self.path = path
        self.schemaVersion = plan.schemaVersion
        self.name = plan.name
        self.variables = plan.variables
        self.stepCount = plan.steps.count
        self.actions = plan.steps.map(\.action.rawValue)
        self.target = plan.target
        let planValidationErrors = TKReplayStepExecution.planValidationErrors(for: plan.steps)
        self.steps = plan.steps.enumerated().map { offset, step in
            TKReplayPlanStepSummary(
                index: offset + 1,
                planName: plan.name,
                step: step,
                extraValidationErrors: planValidationErrors[offset] ?? []
            )
        }
    }
}

public struct TKReplayPlanStepSummary: Codable, Equatable {
    public let index: Int
    public let id: String?
    public let name: String?
    public let action: String
    public let command: String
    public let argv: [String]
    public let category: String
    public let workflowCategories: [String]
    public let requires: [String]
    public let expectedArtifacts: [String]
    public let stopConditions: [String]
    public let validationErrors: [TKReplayPlanStepValidationError]

    enum CodingKeys: String, CodingKey {
        case index
        case id
        case name
        case action
        case command
        case argv
        case category
        case workflowCategories
        case requires
        case expectedArtifacts
        case stopConditions
        case validationErrors
    }

    public init(
        index: Int,
        planName: String?,
        step: TKReplayPlanStep,
        extraValidationErrors: [TKReplayPlanStepValidationError] = []
    ) {
        let descriptor = TKReplayStepExecution.inspectDescriptor(for: step, planName: planName, index: index)

        self.index = index
        self.id = step.id
        self.name = step.name
        self.action = step.action.rawValue
        self.command = descriptor.command
        self.argv = descriptor.argv
        self.category = descriptor.category
        self.workflowCategories = descriptor.workflowCategories
        self.requires = descriptor.requires
        self.expectedArtifacts = descriptor.expectedArtifacts
        self.stopConditions = descriptor.stopConditions
        self.validationErrors = TKReplayStepExecution.validationErrors(for: step) + extraValidationErrors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.index = try container.decode(Int.self, forKey: .index)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.action = try container.decode(String.self, forKey: .action)
        self.command = try container.decode(String.self, forKey: .command)
        self.argv = try container.decode([String].self, forKey: .argv)
        self.category = try container.decode(String.self, forKey: .category)
        self.workflowCategories = try container.decodeIfPresent([String].self, forKey: .workflowCategories)
            ?? TKReplayStepExecution.metadata(argv: argv, action: action).workflowCategories
        self.requires = try container.decode([String].self, forKey: .requires)
        self.expectedArtifacts = try container.decode([String].self, forKey: .expectedArtifacts)
        self.stopConditions = try container.decode([String].self, forKey: .stopConditions)
        self.validationErrors = try container.decodeIfPresent(
            [TKReplayPlanStepValidationError].self,
            forKey: .validationErrors
        ) ?? []
    }
}

public struct TKReplayPlanStepValidationError: Codable, Equatable {
    public let code: String
    public let message: String
    public let field: String?
    public let severity: String

    public init(
        code: String,
        message: String,
        field: String? = nil,
        severity: String = "error"
    ) {
        self.code = code
        self.message = message
        self.field = field
        self.severity = severity
    }
}

public struct TKReplayStepExecutionDescriptor: Codable, Equatable {
    public let command: String
    public let argv: [String]
    public let category: String
    public let workflowCategories: [String]
    public let requires: [String]
    public let expectedArtifacts: [String]
    public let stopConditions: [String]
}

public struct TKReplayStepExecutionMetadata: Codable, Equatable {
    public let category: String
    public let workflowCategories: [String]
    public let requires: [String]
    public let expectedArtifacts: [String]
    public let stopConditions: [String]
}

public enum TKReplayStepExecutionError: Error, Equatable, CustomStringConvertible {
    case missingTapSelector
    case ambiguousTapSelector
    case missingText(action: String)
    case missingWaitCondition
    case ambiguousWaitCondition
    case incompleteCoordinate(action: String)

    public var description: String {
        switch self {
        case .missingTapSelector:
            return "Replay tap step requires a target selector"
        case .ambiguousTapSelector:
            return "Replay tap step requires exactly one selector: text, oid, x/y, axOID, or axLabel"
        case let .missingText(action):
            return "Replay \(action) step requires value or text"
        case .missingWaitCondition:
            return "Replay wait step requires one condition: text, gone, exists, idle, hierarchyChange, or predicate"
        case .ambiguousWaitCondition:
            return "Replay wait step requires exactly one condition: text, gone, exists, idle, hierarchyChange, or predicate"
        case let .incompleteCoordinate(action):
            return "Replay \(action) step requires x and y together"
        }
    }
}

public enum TKReplayStepExecution {
    public static func inspectDescriptor(
        for step: TKReplayPlanStep,
        planName: String?,
        index: Int
    ) -> TKReplayStepExecutionDescriptor {
        let argv = inspectArgv(for: step, planName: planName, index: index)
        let metadata = metadata(argv: argv, action: step.action.rawValue)
        return TKReplayStepExecutionDescriptor(
            command: commandString(argv),
            argv: argv,
            category: metadata.category,
            workflowCategories: metadata.workflowCategories,
            requires: metadata.requires,
            expectedArtifacts: metadata.expectedArtifacts,
            stopConditions: metadata.stopConditions
        )
    }

    public static func argv(
        for step: TKReplayPlanStep,
        planName: String?,
        index: Int,
        variables: [String: String]
    ) throws -> [String] {
        try argv(for: step, planName: planName, index: index, variables: variables, strict: true)
    }

    public static func metadata(argv: [String], action: String) -> TKReplayStepExecutionMetadata {
        let root = rootCommand(argv: argv, action: action)
        return TKReplayStepExecutionMetadata(
            category: category(rootCommand: root, argv: argv),
            workflowCategories: workflowCategories(rootCommand: root, argv: argv),
            requires: requires(argv: argv),
            expectedArtifacts: expectedArtifacts(rootCommand: root, argv: argv),
            stopConditions: stopConditions(rootCommand: root, argv: argv)
        )
    }

    public static func validationErrors(for step: TKReplayPlanStep) -> [TKReplayPlanStepValidationError] {
        var errors: [TKReplayPlanStepValidationError] = []
        switch step.action {
        case .tap:
            let selectorCount = tapSelectorCount(step)
            if selectorCount == 0 {
                errors.append(validationError(.missingTapSelector, field: "selector"))
            } else if selectorCount > 1 {
                errors.append(validationError(.ambiguousTapSelector, field: "selector"))
            }
            appendCoordinateValidationError(for: step, to: &errors)
        case .paste, .type:
            appendCoordinateValidationError(for: step, to: &errors)
            if step.value == nil, step.text == nil {
                errors.append(validationError(.missingText(action: step.action.rawValue), field: "value"))
            }
        case .clear:
            appendCoordinateValidationError(for: step, to: &errors)
        case .wait:
            let conditionCount = waitConditionCount(step)
            if conditionCount == 0 {
                errors.append(validationError(.missingWaitCondition, field: "condition"))
            } else if conditionCount > 1 {
                errors.append(validationError(.ambiguousWaitCondition, field: "condition"))
            }
        case .screenshot, .evidence, .proxyProbe, .proxyServe, .proxyStart, .proxyStatus, .proxyExport, .proxyStop:
            break
        }
        return errors
    }

    public static func planValidationErrors(for steps: [TKReplayPlanStep]) -> [Int: [TKReplayPlanStepValidationError]] {
        var errorsByOffset: [Int: [TKReplayPlanStepValidationError]] = [:]
        var hasProxyStart = false

        for (offset, step) in steps.enumerated() {
            var errors = proxyLifecycleValidationErrors(for: step)
            switch step.action {
            case .proxyExport:
                if !hasProxyStart {
                    errors.append(TKReplayPlanStepValidationError(
                        code: "proxy_export_before_start",
                        message: "Replay proxy-export step requires an earlier proxy-start step in the same plan",
                        field: "action"
                    ))
                }
            case .proxyStart:
                hasProxyStart = true
            default:
                break
            }
            if !errors.isEmpty {
                errorsByOffset[offset] = errors
            }
        }

        return errorsByOffset
    }

    public static func artifactName(planName: String?, step: TKReplayPlanStep, index: Int) -> String {
        sanitizedPathComponent(step.name ?? step.id ?? planName ?? "triton-replay-step-\(index)")
    }

    public static func commandString(_ argv: [String]) -> String {
        argv.map(shellEscaped).joined(separator: " ")
    }

    private static func inspectArgv(for step: TKReplayPlanStep, planName: String?, index: Int) -> [String] {
        (try? argv(for: step, planName: planName, index: index, variables: [:], strict: false)) ?? ["triton", step.action.rawValue, "--json"]
    }

    private static func argv(
        for step: TKReplayPlanStep,
        planName: String?,
        index: Int,
        variables: [String: String],
        strict: Bool
    ) throws -> [String] {
        switch step.action {
        case .tap:
            return try tapArgv(for: step, variables: variables, strict: strict)
        case .paste:
            return try pasteArgv(for: step, variables: variables, strict: strict)
        case .type:
            return try typeArgv(for: step, variables: variables, strict: strict)
        case .clear:
            return try clearArgv(for: step, strict: strict)
        case .wait:
            return try waitArgv(for: step, variables: variables, strict: strict)
        case .screenshot:
            let output = try substituted(
                step.output ?? "/tmp/\(artifactName(planName: planName, step: step, index: index)).png",
                variables: variables,
                strict: strict
            )
            return ["triton", "screenshot", "--output", output, "--json"]
        case .evidence:
            let output = try substituted(
                step.output ?? "/tmp/\(artifactName(planName: planName, step: step, index: index)).tritonevidence",
                variables: variables,
                strict: strict
            )
            var argv = ["triton", "evidence", "--output", output, "--include", step.include ?? "status,list,version,hierarchy,ax,screenshot"]
            if let proxySession = step.proxySession {
                argv += [
                    "--proxy-session",
                    try substituted(proxySession, variables: variables, strict: strict),
                ]
            }
            if let name = step.name ?? planName {
                argv += ["--name", name]
            }
            if let note = step.note {
                argv += ["--note", note]
            }
            return argv + ["--json"]
        case .proxyProbe:
            return try proxyProbeArgv(for: step, variables: variables, strict: strict)
        case .proxyServe:
            return try proxyServeArgv(for: step, variables: variables, strict: strict)
        case .proxyStart:
            return try proxyStartArgv(for: step, variables: variables, strict: strict)
        case .proxyStatus:
            return try proxyStatusArgv(for: step, variables: variables, strict: strict)
        case .proxyExport:
            return try proxyExportArgv(for: step, variables: variables, strict: strict)
        case .proxyStop:
            return try proxyStopArgv(for: step, variables: variables, strict: strict)
        }
    }

    private static func proxyProbeArgv(
        for step: TKReplayPlanStep,
        variables: [String: String],
        strict: Bool
    ) throws -> [String] {
        [
            "triton", "device", "proxy", "probe",
            "--platform", try substituted(step.platform ?? "<platform>", variables: variables, strict: strict),
            "--device", try substituted(step.device ?? "<selector>", variables: variables, strict: strict),
            "--plan-only",
            "--json",
        ]
    }

    private static func proxyServeArgv(
        for step: TKReplayPlanStep,
        variables: [String: String],
        strict: Bool
    ) throws -> [String] {
        let listen = try substituted(step.proxy ?? "<host:port>", variables: variables, strict: strict)
        let output = try substituted(step.output ?? "<proxy-session-dir>", variables: variables, strict: strict)
        let mode = try substituted(step.mode ?? "record", variables: variables, strict: strict)
        return [
            "triton", "device", "proxy", "serve",
            "--listen", listen,
            "--output", output,
            "--mode", mode,
            "--jsonl",
        ]
    }

    private static func proxyStartArgv(
        for step: TKReplayPlanStep,
        variables: [String: String],
        strict: Bool
    ) throws -> [String] {
        [
            "triton", "device", "proxy", "start",
            "--platform", try substituted(step.platform ?? "<platform>", variables: variables, strict: strict),
            "--device", try substituted(step.device ?? "<selector>", variables: variables, strict: strict),
            "--proxy", try substituted(step.proxy ?? "<host:port>", variables: variables, strict: strict),
            "--mode", try substituted(step.mode ?? "record", variables: variables, strict: strict),
            "--output", try substituted(step.output ?? "<proxy-session-dir>", variables: variables, strict: strict),
            "--plan-only",
            "--json",
        ]
    }

    private static func proxyExportArgv(
        for step: TKReplayPlanStep,
        variables: [String: String],
        strict: Bool
    ) throws -> [String] {
        [
            "triton", "device", "proxy", "export",
            "--platform", try substituted(step.platform ?? "<platform>", variables: variables, strict: strict),
            "--device", try substituted(step.device ?? "<selector>", variables: variables, strict: strict),
            "--output", try substituted(step.output ?? "<network-capture.ndjson>", variables: variables, strict: strict),
            "--plan-only",
            "--json",
        ]
    }

    private static func proxyStatusArgv(
        for step: TKReplayPlanStep,
        variables: [String: String],
        strict: Bool
    ) throws -> [String] {
        [
            "triton", "device", "proxy", "status",
            "--platform", try substituted(step.platform ?? "<platform>", variables: variables, strict: strict),
            "--device", try substituted(step.device ?? "<selector>", variables: variables, strict: strict),
            "--json",
        ]
    }

    private static func proxyStopArgv(
        for step: TKReplayPlanStep,
        variables: [String: String],
        strict: Bool
    ) throws -> [String] {
        var argv = [
            "triton", "device", "proxy", "stop",
            "--platform", try substituted(step.platform ?? "<platform>", variables: variables, strict: strict),
            "--device", try substituted(step.device ?? "<selector>", variables: variables, strict: strict),
        ]
        if step.restore != false {
            argv.append("--restore")
        }
        return argv + [
            "--plan-only",
            "--json",
        ]
    }

    private static func tapArgv(for step: TKReplayPlanStep, variables: [String: String], strict: Bool) throws -> [String] {
        if strict {
            let selectorCount = tapSelectorCount(step)
            if selectorCount == 0 {
                throw TKReplayStepExecutionError.missingTapSelector
            }
            if selectorCount > 1 {
                throw TKReplayStepExecutionError.ambiguousTapSelector
            }
            try validateCoordinatePair(step, strict: strict)
        }

        var argv = ["triton", "tap"]
        if let text = step.text {
            argv.append(try substituted(text, variables: variables, strict: strict))
        } else if let x = step.x, let y = step.y {
            argv += ["--x", number(x), "--y", number(y)]
        } else if let oid = step.oid {
            argv += ["--oid", "\(oid)"]
        } else if let axOID = step.axOID {
            argv += ["--ax-oid", "\(axOID)"]
        } else if let axLabel = step.axLabel {
            argv += ["--ax-label", try substituted(axLabel, variables: variables, strict: strict)]
        } else if strict {
            throw TKReplayStepExecutionError.missingTapSelector
        } else {
            argv.append("<selector>")
        }
        return argv + ["--json"]
    }

    private static func pasteArgv(for step: TKReplayPlanStep, variables: [String: String], strict: Bool) throws -> [String] {
        try validateCoordinatePair(step, strict: strict)
        guard let rawValue = step.value ?? step.text else {
            if strict {
                throw TKReplayStepExecutionError.missingText(action: step.action.rawValue)
            }
            var argv = ["triton", "paste", "<text>"]
            try appendFocusArgs(step, to: &argv, strict: strict)
            return argv + ["--json"]
        }
        let value = try substituted(rawValue, variables: variables, strict: strict)
        var argv = ["triton", "paste"]
        if step.secure == true {
            argv += ["--secure", step.redactedValue(substitutedValue: value)]
        } else {
            argv.append(value)
        }
        try appendFocusArgs(step, to: &argv, strict: strict)
        return argv + ["--json"]
    }

    private static func typeArgv(for step: TKReplayPlanStep, variables: [String: String], strict: Bool) throws -> [String] {
        try validateCoordinatePair(step, strict: strict)
        guard let rawValue = step.value ?? step.text else {
            if strict {
                throw TKReplayStepExecutionError.missingText(action: step.action.rawValue)
            }
            return ["triton", "type", "--text", "<text>", "--json"]
        }
        let value = try substituted(rawValue, variables: variables, strict: strict)
        var argv = ["triton", "type", "--text", step.redactedValue(substitutedValue: value)]
        if step.secure == true {
            argv.append("--secure")
        }
        if let oid = step.oid {
            argv += ["--oid", "\(oid)"]
        }
        return argv + ["--json"]
    }

    private static func clearArgv(for step: TKReplayPlanStep, strict: Bool) throws -> [String] {
        try validateCoordinatePair(step, strict: strict)
        var argv = ["triton", "clear"]
        try appendFocusArgs(step, to: &argv, strict: strict)
        return argv + ["--json"]
    }

    private static func waitArgv(for step: TKReplayPlanStep, variables: [String: String], strict: Bool) throws -> [String] {
        if strict {
            let conditionCount = waitConditionCount(step)
            if conditionCount == 0 {
                throw TKReplayStepExecutionError.missingWaitCondition
            }
            if conditionCount > 1 {
                throw TKReplayStepExecutionError.ambiguousWaitCondition
            }
        }

        var argv = ["triton", "wait"]
        switch step.waitCondition {
        case .text:
            argv += ["--text", try substituted(step.text ?? "", variables: variables, strict: strict)]
        case .gone:
            argv += ["--gone", try substituted(step.gone ?? "", variables: variables, strict: strict)]
        case .exists:
            argv += ["--exists", try substituted(step.exists ?? "", variables: variables, strict: strict)]
        case .idle:
            argv.append("--idle")
        case .hierarchyChange:
            argv.append("--hierarchy-change")
        case .predicate:
            argv += ["--predicate", try substituted(step.predicate ?? "", variables: variables, strict: strict)]
        case nil:
            if strict {
                throw TKReplayStepExecutionError.missingWaitCondition
            }
            argv.append("<condition>")
        }
        if let role = step.role {
            argv += ["--role", try substituted(role, variables: variables, strict: strict)]
        }
        return argv + [
            "--timeout", number(step.timeout ?? 10),
            "--interval", number(step.interval ?? 0.5),
            "--json",
        ]
    }

    private static func appendFocusArgs(_ step: TKReplayPlanStep, to argv: inout [String], strict: Bool) throws {
        if let x = step.x, let y = step.y {
            argv += ["--x", number(x), "--y", number(y)]
        } else if step.x != nil || step.y != nil, !strict {
            argv += ["--x", step.x.map(number) ?? "<x>", "--y", step.y.map(number) ?? "<y>"]
        }
        if let oid = step.oid {
            argv += ["--oid", "\(oid)"]
        }
    }

    private static func validateCoordinatePair(_ step: TKReplayPlanStep, strict: Bool) throws {
        if strict, (step.x == nil) != (step.y == nil) {
            throw TKReplayStepExecutionError.incompleteCoordinate(action: step.action.rawValue)
        }
    }

    private static func appendCoordinateValidationError(
        for step: TKReplayPlanStep,
        to errors: inout [TKReplayPlanStepValidationError]
    ) {
        if (step.x == nil) != (step.y == nil) {
            errors.append(validationError(.incompleteCoordinate(action: step.action.rawValue), field: "x/y"))
        }
    }

    private static func tapSelectorCount(_ step: TKReplayPlanStep) -> Int {
        [
            step.text != nil,
            step.oid != nil,
            step.x != nil || step.y != nil,
            step.axOID != nil,
            step.axLabel != nil,
        ].filter { $0 }.count
    }

    private static func waitConditionCount(_ step: TKReplayPlanStep) -> Int {
        [
            step.text != nil,
            step.gone != nil,
            step.exists != nil,
            step.idle == true,
            step.hierarchyChange == true,
            step.predicate != nil,
        ].filter { $0 }.count
    }

    private static func validationError(
        _ error: TKReplayStepExecutionError,
        field: String
    ) -> TKReplayPlanStepValidationError {
        TKReplayPlanStepValidationError(
            code: validationErrorCode(for: error),
            message: error.description,
            field: field
        )
    }

    private static func proxyLifecycleValidationErrors(for step: TKReplayPlanStep) -> [TKReplayPlanStepValidationError] {
        switch step.action {
        case .proxyProbe:
            return requiredProxyTargetErrors(step)
        case .proxyServe:
            return requiredProxyEndpointError(step) + requiredProxyOutputError(step)
        case .proxyStart:
            return requiredProxyTargetErrors(step) + requiredProxyEndpointError(step) + requiredProxyOutputError(step)
        case .proxyStatus:
            return requiredProxyTargetErrors(step)
        case .proxyExport:
            return requiredProxyTargetErrors(step) + requiredProxyOutputError(step)
        case .proxyStop:
            var errors = requiredProxyTargetErrors(step)
            if step.restore != true {
                errors.append(TKReplayPlanStepValidationError(
                    code: "proxy_stop_restore_required",
                    message: "Replay proxy-stop step requires restore=true so dry-run emits an explicit restore policy",
                    field: "restore"
                ))
            }
            return errors
        case .tap, .paste, .type, .clear, .wait, .screenshot, .evidence:
            return []
        }
    }

    private static func requiredProxyTargetErrors(_ step: TKReplayPlanStep) -> [TKReplayPlanStepValidationError] {
        var errors: [TKReplayPlanStepValidationError] = []
        if isBlank(step.platform) {
            errors.append(TKReplayPlanStepValidationError(
                code: "missing_proxy_platform",
                message: "Replay \(step.action.rawValue) step requires platform",
                field: "platform"
            ))
        }
        if isBlank(step.device) {
            errors.append(TKReplayPlanStepValidationError(
                code: "missing_proxy_device",
                message: "Replay \(step.action.rawValue) step requires device selector",
                field: "device"
            ))
        }
        return errors
    }

    private static func requiredProxyEndpointError(_ step: TKReplayPlanStep) -> [TKReplayPlanStepValidationError] {
        if isBlank(step.proxy) {
            return [TKReplayPlanStepValidationError(
                code: "missing_proxy_endpoint",
                message: "Replay \(step.action.rawValue) step requires proxy endpoint",
                field: "proxy"
            )]
        }
        return []
    }

    private static func requiredProxyOutputError(_ step: TKReplayPlanStep) -> [TKReplayPlanStepValidationError] {
        if isBlank(step.output) {
            return [TKReplayPlanStepValidationError(
                code: "missing_proxy_output",
                message: "Replay \(step.action.rawValue) step requires output path",
                field: "output"
            )]
        }
        return []
    }

    private static func isBlank(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func validationErrorCode(for error: TKReplayStepExecutionError) -> String {
        switch error {
        case .missingTapSelector:
            return "missing_tap_selector"
        case .ambiguousTapSelector:
            return "ambiguous_tap_selector"
        case .missingText:
            return "missing_text"
        case .missingWaitCondition:
            return "missing_wait_condition"
        case .ambiguousWaitCondition:
            return "ambiguous_wait_condition"
        case .incompleteCoordinate:
            return "incomplete_coordinate"
        }
    }

    private static func substituted(_ value: String, variables: [String: String], strict: Bool) throws -> String {
        strict ? try TKReplaySubstituteVariables(value, variables: variables) : value
    }

    private static func category(rootCommand: String, argv: [String]) -> String {
        if isDeviceProxyServe(argv) || isDeviceProxyExport(argv) {
            return "archive"
        }
        if isDeviceProxyCommand(argv) {
            return "prepare-target"
        }
        return TKCommandRecoveryCommand.category(forRootCommand: rootCommand) ?? "replay"
    }

    private static func requires(argv: [String]) -> [String] {
        if isDeviceProxyServe(argv) {
            return ["cli.available"]
        }
        if isDeviceProxyCommand(argv) {
            return ["cli.available", "target.ready"]
        }
        return ["cli.available", "server.reachable", "target.ready", "runtime.connected"]
    }

    private static func expectedArtifacts(rootCommand: String, argv: [String]) -> [String] {
        var values: [String]
        if isDeviceProxyServe(argv) || isDeviceProxyExport(argv) {
            values = ["stdout-json", "network-capture"]
        } else if isDeviceProxyStart(argv) || isDeviceProxyStatus(argv) || isDeviceProxyDoctor(argv) || isDeviceProxyProbe(argv) {
            values = ["stdout-json", "host-device-proxy"]
        } else if isDeviceProxyStop(argv) {
            values = ["stdout-json", "proxy-restore"]
        } else {
            switch rootCommand {
        case "tap", "paste", "type", "clear", "input":
            values = ["stdout-json", "input-result"]
        case "wait":
            values = ["stdout-json", "wait-result"]
        case "screenshot":
            values = ["stdout-json", "screenshot"]
        case "evidence", "capture":
            values = ["stdout-json", "evidence-bundle"]
        default:
            values = ["stdout-json"]
            }
        }
        if includesNetworkProxySession(argv) {
            values.append("network.proxy-session")
            values.append("network-capture")
        }
        return unique(values)
    }

    private static func workflowCategories(rootCommand: String, argv: [String]) -> [String] {
        let taxonomy = [
            "action", "app", "assert", "evidence", "observe", "project",
            "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
        ]
        let values: Set<String>

        if isDeviceProxyCommand(argv) {
            values = ["evidence", "target"]
        } else {
            switch rootCommand {
        case "tap", "paste", "type", "clear", "input":
            values = ["action", "assert", "evidence"]
        case "wait":
            values = ["observe", "assert", "evidence"]
        case "screenshot":
            values = ["observe", "evidence"]
        case "evidence", "capture":
            values = ["evidence", "replay"]
        default:
            values = ["replay"]
            }
        }

        return taxonomy.filter { values.contains($0) }
    }

    private static func stopConditions(rootCommand: String, argv: [String]) -> [String] {
        var values = ["command.failed", "server.unavailable", "target.unavailable"]
        if isDeviceProxyCommand(argv) {
            values.append("artifact.write-failed")
            return unique(values)
        }
        switch rootCommand {
        case "wait":
            values.append("timeout")
        case "screenshot", "evidence", "capture":
            values.append("artifact.write-failed")
        case "replay", "smoke":
            values.append("step.failed")
        default:
            break
        }
        return values
    }

    private static func isDeviceProxyCommand(_ argv: [String]) -> Bool {
        argv.count >= 4 && argv[0] == "triton" && argv[1] == "device" && argv[2] == "proxy"
    }

    private static func isDeviceProxyDoctor(_ argv: [String]) -> Bool {
        isDeviceProxyCommand(argv) && argv[3] == "doctor"
    }

    private static func isDeviceProxyProbe(_ argv: [String]) -> Bool {
        isDeviceProxyCommand(argv) && argv[3] == "probe"
    }

    private static func isDeviceProxyServe(_ argv: [String]) -> Bool {
        isDeviceProxyCommand(argv) && argv[3] == "serve"
    }

    private static func isDeviceProxyStart(_ argv: [String]) -> Bool {
        isDeviceProxyCommand(argv) && argv[3] == "start"
    }

    private static func isDeviceProxyStatus(_ argv: [String]) -> Bool {
        isDeviceProxyCommand(argv) && argv[3] == "status"
    }

    private static func isDeviceProxyExport(_ argv: [String]) -> Bool {
        isDeviceProxyCommand(argv) && argv[3] == "export"
    }

    private static func isDeviceProxyStop(_ argv: [String]) -> Bool {
        isDeviceProxyCommand(argv) && argv[3] == "stop"
    }

    private static func includesNetworkProxySession(_ argv: [String]) -> Bool {
        for (index, token) in argv.enumerated() {
            if token == "--include",
               argv.indices.contains(index + 1),
               argv[index + 1].split(separator: ",").map(String.init).contains("network.proxy-session") {
                return true
            }
            if token.hasPrefix("--include="),
               token.dropFirst("--include=".count).split(separator: ",").map(String.init).contains("network.proxy-session") {
                return true
            }
        }
        return false
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func rootCommand(argv: [String], action: String) -> String {
        guard argv.first == "triton", argv.count > 1 else {
            return action
        }
        return argv[1]
    }

    private static func sanitizedPathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "triton-replay" : collapsed
    }

    private static func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private static func shellEscaped(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: #"'\"$`<>|&;()"#))) == nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public struct TKReplayFileArtifact: Codable, Equatable {
    public let path: String
    public let bytes: Int?
    public let contentType: String?

    public init(path: String, bytes: Int? = nil, contentType: String? = nil) {
        self.path = path
        self.bytes = bytes
        self.contentType = contentType
    }
}

public struct TKReplayStepResult: Codable, Equatable {
    public let index: Int
    public let action: String
    public let name: String?
    public let ok: Bool
    public let dryRun: Bool
    public let elapsedMs: Int
    public let command: [String]
    public let argv: [String]
    public let category: String
    public let workflowCategories: [String]
    public let requires: [String]
    public let expectedArtifacts: [String]
    public let stopConditions: [String]
    public let failureCode: String?
    public let error: TKCLIErrorDetail?
    public let message: String?
    public let redactedValue: String?
    public let input: TKInputResult?
    public let wait: TKWaitResult?
    public let file: TKReplayFileArtifact?
    public let evidence: TKEvidenceManifest?

    enum CodingKeys: String, CodingKey {
        case index
        case action
        case name
        case ok
        case dryRun
        case elapsedMs
        case command
        case argv
        case category
        case workflowCategories
        case requires
        case expectedArtifacts
        case stopConditions
        case failureCode
        case error
        case message
        case redactedValue
        case input
        case wait
        case file
        case evidence
    }

    public init(
        index: Int,
        action: String,
        name: String? = nil,
        ok: Bool,
        dryRun: Bool,
        elapsedMs: Int,
        command: [String],
        argv: [String]? = nil,
        category: String? = nil,
        workflowCategories: [String]? = nil,
        requires: [String]? = nil,
        expectedArtifacts: [String]? = nil,
        stopConditions: [String]? = nil,
        failureCode: String? = nil,
        error: TKCLIErrorDetail? = nil,
        message: String? = nil,
        redactedValue: String? = nil,
        input: TKInputResult? = nil,
        wait: TKWaitResult? = nil,
        file: TKReplayFileArtifact? = nil,
        evidence: TKEvidenceManifest? = nil
    ) {
        self.index = index
        self.action = action
        self.name = name
        self.ok = ok
        self.dryRun = dryRun
        self.elapsedMs = elapsedMs
        self.command = command
        self.argv = argv ?? command
        let metadata = TKReplayStepExecution.metadata(argv: self.argv, action: action)
        self.category = category ?? metadata.category
        self.workflowCategories = workflowCategories ?? metadata.workflowCategories
        self.requires = requires ?? metadata.requires
        self.expectedArtifacts = expectedArtifacts ?? metadata.expectedArtifacts
        self.stopConditions = stopConditions ?? metadata.stopConditions
        self.error = error
        self.failureCode = failureCode ?? error?.code ?? Self.defaultFailureCode(
            ok: ok,
            action: action,
            input: input,
            wait: wait,
            file: file,
            evidence: evidence
        )
        self.message = message
        self.redactedValue = redactedValue
        self.input = input
        self.wait = wait
        self.file = file
        self.evidence = evidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(String.self, forKey: .action)
        let decodedCommand = try container.decodeIfPresent([String].self, forKey: .command)
        let decodedArgv = try container.decodeIfPresent([String].self, forKey: .argv)
        let command: [String]
        if let decodedCommand {
            command = decodedCommand
        } else if let decodedArgv {
            command = decodedArgv
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.command,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Expected command or argv")
            )
        }
        let argv = decodedArgv ?? command

        self.index = try container.decode(Int.self, forKey: .index)
        self.action = action
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.dryRun = try container.decode(Bool.self, forKey: .dryRun)
        self.elapsedMs = try container.decode(Int.self, forKey: .elapsedMs)
        self.command = command
        self.argv = argv
        let metadata = TKReplayStepExecution.metadata(argv: argv, action: action)
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? metadata.category
        self.workflowCategories = try container.decodeIfPresent([String].self, forKey: .workflowCategories)
            ?? metadata.workflowCategories
        self.requires = try container.decodeIfPresent([String].self, forKey: .requires) ?? metadata.requires
        self.expectedArtifacts = try container.decodeIfPresent([String].self, forKey: .expectedArtifacts) ?? metadata.expectedArtifacts
        self.stopConditions = try container.decodeIfPresent([String].self, forKey: .stopConditions) ?? metadata.stopConditions
        let decodedError = try container.decodeIfPresent(TKCLIErrorDetail.self, forKey: .error)
        let decodedInput = try container.decodeIfPresent(TKInputResult.self, forKey: .input)
        let decodedWait = try container.decodeIfPresent(TKWaitResult.self, forKey: .wait)
        let decodedFile = try container.decodeIfPresent(TKReplayFileArtifact.self, forKey: .file)
        let decodedEvidence = try container.decodeIfPresent(TKEvidenceManifest.self, forKey: .evidence)
        self.error = decodedError
        self.failureCode = try container.decodeIfPresent(String.self, forKey: .failureCode)
            ?? decodedError?.code
            ?? Self.defaultFailureCode(
                ok: self.ok,
                action: action,
                input: decodedInput,
                wait: decodedWait,
                file: decodedFile,
                evidence: decodedEvidence
            )
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.redactedValue = try container.decodeIfPresent(String.self, forKey: .redactedValue)
        self.input = decodedInput
        self.wait = decodedWait
        self.file = decodedFile
        self.evidence = decodedEvidence
    }

    private static func defaultFailureCode(
        ok: Bool,
        action: String,
        input: TKInputResult?,
        wait: TKWaitResult?,
        file: TKReplayFileArtifact?,
        evidence: TKEvidenceManifest?
    ) -> String? {
        guard !ok else { return nil }
        if let wait, wait.timedOut {
            return "timeout"
        }
        if input != nil {
            return "action_failed"
        }
        if action == "screenshot", file == nil {
            return "artifact_write_failed"
        }
        if let evidence, !evidence.ok {
            return "request_failed"
        }
        return "step_failed"
    }
}

public struct TKReplayResult: Codable, Equatable {
    public let ok: Bool
    public let dryRun: Bool
    public let planName: String?
    public let stepCount: Int
    public let executedCount: Int
    public let failedStepIndex: Int?
    public let failureCode: String?
    public let failureError: TKCLIErrorDetail?
    public let failurePrimaryWorkflowCategory: String?
    public let failureWorkflowCategories: [String]
    public let failurePrimaryRecoveryCategory: String?
    public let failureRecoveryCategories: [String]
    public let failurePrimaryHint: String?
    public let failurePrimaryEndpoint: String?
    public let failurePrimaryNextAction: TKCLINextAction?
    public let failurePrimaryArtifact: TKEvidenceArtifactSummary?
    public let failurePrimaryArtifacts: [TKEvidenceArtifactSummary]
    public let elapsedMs: Int
    public let steps: [TKReplayStepResult]
    public let failurePrimarySuggestedCommand: String?
    public let suggestedCommands: [String]
    public let failurePrimaryRecoveryCommand: TKCommandRecoveryCommand?
    public let recoveryCommands: [TKCommandRecoveryCommand]

    enum CodingKeys: String, CodingKey {
        case ok
        case dryRun
        case planName
        case stepCount
        case executedCount
        case failedStepIndex
        case failureCode
        case failureError
        case failurePrimaryWorkflowCategory
        case failureWorkflowCategories
        case failurePrimaryRecoveryCategory
        case failureRecoveryCategories
        case failurePrimaryHint
        case failurePrimaryEndpoint
        case failurePrimaryNextAction
        case failurePrimaryArtifact
        case failurePrimaryArtifacts
        case elapsedMs
        case steps
        case failurePrimarySuggestedCommand
        case suggestedCommands
        case failurePrimaryRecoveryCommand
        case recoveryCommands
    }

    public init(
        ok: Bool,
        dryRun: Bool,
        planName: String?,
        stepCount: Int,
        executedCount: Int,
        failedStepIndex: Int?,
        failureCode: String? = nil,
        failureError: TKCLIErrorDetail? = nil,
        failurePrimaryWorkflowCategory: String? = nil,
        failureWorkflowCategories: [String]? = nil,
        failurePrimaryRecoveryCategory: String? = nil,
        failureRecoveryCategories: [String]? = nil,
        failurePrimaryHint: String? = nil,
        failurePrimaryEndpoint: String? = nil,
        failurePrimaryNextAction: TKCLINextAction? = nil,
        failurePrimaryArtifact: TKEvidenceArtifactSummary? = nil,
        failurePrimaryArtifacts: [TKEvidenceArtifactSummary]? = nil,
        elapsedMs: Int,
        steps: [TKReplayStepResult],
        failurePrimarySuggestedCommand: String? = nil,
        suggestedCommands: [String] = [],
        failurePrimaryRecoveryCommand: TKCommandRecoveryCommand? = nil,
        recoveryCommands: [TKCommandRecoveryCommand]? = nil
    ) {
        self.ok = ok
        self.dryRun = dryRun
        self.planName = planName
        self.stepCount = stepCount
        self.executedCount = executedCount
        self.failedStepIndex = failedStepIndex
        self.failureCode = failureCode ?? Self.defaultFailureCode(steps: steps, failedStepIndex: failedStepIndex)
        self.failureError = failureError ?? Self.defaultFailureError(steps: steps, failedStepIndex: failedStepIndex)
        self.failureWorkflowCategories = failureWorkflowCategories ?? Self.defaultFailureWorkflowCategories(
            steps: steps,
            failedStepIndex: failedStepIndex
        )
        self.failurePrimaryWorkflowCategory = failurePrimaryWorkflowCategory ?? self.failureWorkflowCategories.first
        self.failurePrimaryHint = failurePrimaryHint ?? self.failureError?.hint
        self.failurePrimaryEndpoint = failurePrimaryEndpoint ?? self.failureError?.endpoint
        self.failurePrimaryNextAction = failurePrimaryNextAction ?? self.failureError?.nextAction
        self.failurePrimaryArtifacts = failurePrimaryArtifacts ?? Self.defaultFailurePrimaryArtifacts(
            steps: steps,
            failedStepIndex: failedStepIndex
        )
        self.elapsedMs = elapsedMs
        self.steps = steps
        self.suggestedCommands = Self.normalizedSuggestedCommands(
            suggestedCommands,
            failureError: self.failureError
        )
        self.failurePrimarySuggestedCommand = failurePrimarySuggestedCommand ?? self.suggestedCommands.first
        self.recoveryCommands = Self.normalizedRecoveryCommands(
            recoveryCommands,
            suggestedCommands: self.suggestedCommands,
            failureError: self.failureError
        )
        self.failurePrimaryRecoveryCommand = failurePrimaryRecoveryCommand ?? self.recoveryCommands.first
        self.failureRecoveryCategories = Self.normalizedFailureRecoveryCategories(
            failureRecoveryCategories,
            failureCode: self.failureCode,
            failureError: self.failureError,
            recoveryCommands: self.recoveryCommands
        )
        self.failurePrimaryRecoveryCategory = failurePrimaryRecoveryCategory ?? self.failureRecoveryCategories.first
        self.failurePrimaryArtifact = failurePrimaryArtifact ?? self.failurePrimaryArtifacts.first
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let steps = try container.decode([TKReplayStepResult].self, forKey: .steps)
        let failedStepIndex = try container.decodeIfPresent(Int.self, forKey: .failedStepIndex)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.dryRun = try container.decode(Bool.self, forKey: .dryRun)
        self.planName = try container.decodeIfPresent(String.self, forKey: .planName)
        self.stepCount = try container.decode(Int.self, forKey: .stepCount)
        self.executedCount = try container.decode(Int.self, forKey: .executedCount)
        self.failedStepIndex = failedStepIndex
        self.failureCode = try container.decodeIfPresent(String.self, forKey: .failureCode)
            ?? Self.defaultFailureCode(steps: steps, failedStepIndex: failedStepIndex)
        self.failureError = try container.decodeIfPresent(TKCLIErrorDetail.self, forKey: .failureError)
            ?? Self.defaultFailureError(steps: steps, failedStepIndex: failedStepIndex)
        self.failureWorkflowCategories = try container.decodeIfPresent([String].self, forKey: .failureWorkflowCategories)
            ?? Self.defaultFailureWorkflowCategories(steps: steps, failedStepIndex: failedStepIndex)
        self.failurePrimaryWorkflowCategory = try container.decodeIfPresent(String.self, forKey: .failurePrimaryWorkflowCategory)
            ?? self.failureWorkflowCategories.first
        self.failurePrimaryHint = try container.decodeIfPresent(String.self, forKey: .failurePrimaryHint)
            ?? self.failureError?.hint
        self.failurePrimaryEndpoint = try container.decodeIfPresent(String.self, forKey: .failurePrimaryEndpoint)
            ?? self.failureError?.endpoint
        self.failurePrimaryNextAction = try container.decodeIfPresent(TKCLINextAction.self, forKey: .failurePrimaryNextAction)
            ?? self.failureError?.nextAction
        self.failurePrimaryArtifacts = try container.decodeIfPresent([TKEvidenceArtifactSummary].self, forKey: .failurePrimaryArtifacts)
            ?? Self.defaultFailurePrimaryArtifacts(steps: steps, failedStepIndex: failedStepIndex)
        self.elapsedMs = try container.decode(Int.self, forKey: .elapsedMs)
        self.steps = steps
        self.suggestedCommands = Self.normalizedSuggestedCommands(
            try container.decodeIfPresent([String].self, forKey: .suggestedCommands) ?? [],
            failureError: self.failureError
        )
        self.failurePrimarySuggestedCommand = try container.decodeIfPresent(String.self, forKey: .failurePrimarySuggestedCommand)
            ?? self.suggestedCommands.first
        self.recoveryCommands = Self.normalizedRecoveryCommands(
            try container.decodeIfPresent([TKCommandRecoveryCommand].self, forKey: .recoveryCommands),
            suggestedCommands: self.suggestedCommands,
            failureError: self.failureError
        )
        self.failurePrimaryRecoveryCommand = try container.decodeIfPresent(TKCommandRecoveryCommand.self, forKey: .failurePrimaryRecoveryCommand)
            ?? self.recoveryCommands.first
        self.failureRecoveryCategories = Self.normalizedFailureRecoveryCategories(
            try container.decodeIfPresent([String].self, forKey: .failureRecoveryCategories),
            failureCode: self.failureCode,
            failureError: self.failureError,
            recoveryCommands: self.recoveryCommands
        )
        self.failurePrimaryRecoveryCategory = try container.decodeIfPresent(String.self, forKey: .failurePrimaryRecoveryCategory)
            ?? self.failureRecoveryCategories.first
        self.failurePrimaryArtifact = try container.decodeIfPresent(TKEvidenceArtifactSummary.self, forKey: .failurePrimaryArtifact)
            ?? self.failurePrimaryArtifacts.first
    }

    private static func defaultFailureWorkflowCategories(
        steps: [TKReplayStepResult],
        failedStepIndex: Int?
    ) -> [String] {
        guard let failedStep = failedStep(steps: steps, failedStepIndex: failedStepIndex) else {
            return []
        }
        return failedStep.workflowCategories
    }

    private static func defaultFailureCode(
        steps: [TKReplayStepResult],
        failedStepIndex: Int?
    ) -> String? {
        failedStep(steps: steps, failedStepIndex: failedStepIndex)?.failureCode
    }

    private static func defaultFailureError(
        steps: [TKReplayStepResult],
        failedStepIndex: Int?
    ) -> TKCLIErrorDetail? {
        failedStep(steps: steps, failedStepIndex: failedStepIndex)?.error
    }

    private static func defaultFailurePrimaryArtifacts(
        steps: [TKReplayStepResult],
        failedStepIndex: Int?
    ) -> [TKEvidenceArtifactSummary] {
        guard failedStepIndex != nil else { return [] }
        var artifacts: [TKEvidenceArtifactSummary] = []
        var seen = Set<String>()

        for step in steps.reversed() {
            if let evidence = step.evidence {
                for artifact in evidence.primaryArtifacts {
                    let key = "\(artifact.kind)|\(artifact.path)"
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    artifacts.append(artifact)
                    if artifacts.count >= 5 { return artifacts }
                }
            } else if let file = step.file {
                let artifact = file.artifactSummary
                let key = "\(artifact.kind)|\(artifact.path)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                artifacts.append(artifact)
                if artifacts.count >= 5 { return artifacts }
            }
        }

        return artifacts
    }

    private static func normalizedFailureRecoveryCategories(
        _ categories: [String]?,
        failureCode: String?,
        failureError: TKCLIErrorDetail?,
        recoveryCommands: [TKCommandRecoveryCommand]
    ) -> [String] {
        let familyCategories = categories ?? (failureCode.map(TKCommandRecoveryCommand.recoveryCategories(forFailureCode:)) ?? [])
        let recoveryCategories = uniqueOrderedCategories(from: recoveryCommands.map(\.category))
        let nextActionCategory = failureError?.nextAction?.category

        if nextActionCategory == nil {
            return familyCategories
        }

        var normalized: [String] = []
        var seen = Set<String>()

        func append(_ category: String?) {
            guard let category, !seen.contains(category) else { return }
            seen.insert(category)
            normalized.append(category)
        }

        append(nextActionCategory)
        for category in recoveryCategories {
            append(category)
        }
        for category in familyCategories {
            append(category)
        }
        return normalized
    }

    private static func normalizedSuggestedCommands(
        _ commands: [String],
        failureError: TKCLIErrorDetail?
    ) -> [String] {
        var normalized = commands
        if let nextActionCommand = nextActionCommandString(from: failureError) {
            normalized.insert(nextActionCommand, at: 0)
        }

        var unique: [String] = []
        var seen = Set<String>()
        for command in normalized where !seen.contains(command) {
            seen.insert(command)
            unique.append(command)
        }
        return unique
    }

    private static func normalizedRecoveryCommands(
        _ recoveryCommands: [TKCommandRecoveryCommand]?,
        suggestedCommands: [String],
        failureError: TKCLIErrorDetail?
    ) -> [TKCommandRecoveryCommand] {
        var normalized = recoveryCommands ?? suggestedCommands.compactMap(TKCommandRecoveryCommand.init(commandString:))
        if let nextActionCommand = nextActionCommandString(from: failureError),
           let nextActionRecoveryCommand = TKCommandRecoveryCommand(commandString: nextActionCommand) {
            normalized.removeAll { $0.command == nextActionRecoveryCommand.command }
            normalized.insert(nextActionRecoveryCommand, at: 0)
        }

        var unique: [TKCommandRecoveryCommand] = []
        var seen = Set<String>()
        for recoveryCommand in normalized where !seen.contains(recoveryCommand.command) {
            seen.insert(recoveryCommand.command)
            unique.append(recoveryCommand)
        }
        return unique
    }

    private static func nextActionCommandString(from failureError: TKCLIErrorDetail?) -> String? {
        guard let nextAction = failureError?.nextAction else { return nil }
        return (["triton", nextAction.command] + nextAction.args).joined(separator: " ")
    }

    private static func uniqueOrderedCategories(from categories: [String]) -> [String] {
        var unique: [String] = []
        var seen = Set<String>()
        for category in categories where !seen.contains(category) {
            seen.insert(category)
            unique.append(category)
        }
        return unique
    }

    private static func failedStep(
        steps: [TKReplayStepResult],
        failedStepIndex: Int?
    ) -> TKReplayStepResult? {
        guard let failedStepIndex else { return nil }
        return steps.first { $0.index == failedStepIndex }
    }
}

private extension TKReplayFileArtifact {
    var artifactSummary: TKEvidenceArtifactSummary {
        let kind: String
        if contentType?.hasPrefix("image/") == true {
            kind = "screenshot"
        } else {
            kind = "file"
        }
        return TKEvidenceArtifactSummary(
            kind: kind,
            path: path,
            contentType: contentType,
            bytes: bytes
        )
    }
}

public struct TKReplayVariableError: Error, Equatable, CustomStringConvertible {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public var description: String {
        "Missing replay variable: \(name)"
    }
}

public func TKReplaySubstituteVariables(_ value: String, variables: [String: String]) throws -> String {
    var output = ""
    var index = value.startIndex

    while index < value.endIndex {
        if value[index] == "$",
           value.index(after: index) < value.endIndex,
           value[value.index(after: index)] == "{" {
            let nameStart = value.index(index, offsetBy: 2)
            guard let close = value[nameStart...].firstIndex(of: "}") else {
                output.append(value[index])
                index = value.index(after: index)
                continue
            }
            let name = String(value[nameStart..<close])
            guard let replacement = variables[name] else {
                throw TKReplayVariableError(name: name)
            }
            output.append(replacement)
            index = value.index(after: close)
        } else {
            output.append(value[index])
            index = value.index(after: index)
        }
    }

    return output
}
