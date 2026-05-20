import Foundation

public enum TKReplayAction: String, Codable, CaseIterable {
    case tap
    case paste
    case type
    case clear
    case wait
    case screenshot
    case evidence
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

    public init(ok: Bool, path: String, plan: TKReplayPlan) {
        self.ok = ok
        self.path = path
        self.schemaVersion = plan.schemaVersion
        self.name = plan.name
        self.variables = plan.variables
        self.stepCount = plan.steps.count
        self.actions = plan.steps.map(\.action.rawValue)
        self.target = plan.target
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
    public let message: String?
    public let redactedValue: String?
    public let input: TKInputResult?
    public let wait: TKWaitResult?
    public let file: TKReplayFileArtifact?
    public let evidence: TKEvidenceManifest?

    public init(
        index: Int,
        action: String,
        name: String? = nil,
        ok: Bool,
        dryRun: Bool,
        elapsedMs: Int,
        command: [String],
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
        self.message = message
        self.redactedValue = redactedValue
        self.input = input
        self.wait = wait
        self.file = file
        self.evidence = evidence
    }
}

public struct TKReplayResult: Codable, Equatable {
    public let ok: Bool
    public let dryRun: Bool
    public let planName: String?
    public let stepCount: Int
    public let executedCount: Int
    public let failedStepIndex: Int?
    public let elapsedMs: Int
    public let steps: [TKReplayStepResult]

    public init(
        ok: Bool,
        dryRun: Bool,
        planName: String?,
        stepCount: Int,
        executedCount: Int,
        failedStepIndex: Int?,
        elapsedMs: Int,
        steps: [TKReplayStepResult]
    ) {
        self.ok = ok
        self.dryRun = dryRun
        self.planName = planName
        self.stepCount = stepCount
        self.executedCount = executedCount
        self.failedStepIndex = failedStepIndex
        self.elapsedMs = elapsedMs
        self.steps = steps
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
