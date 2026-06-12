import Foundation

public struct TKCLINextAction: Codable, Equatable {
    public let command: String
    public let args: [String]
    public let category: String
    public let requiresLongRunningProcess: Bool
    public let readyEvents: [String]
    public let finalEvents: [String]
    public let terminationSignals: [String]

    enum CodingKeys: String, CodingKey {
        case command
        case args
        case category
        case requiresLongRunningProcess
        case readyEvents
        case finalEvents
        case terminationSignals
    }

    public init(
        command: String,
        args: [String],
        category: String? = nil,
        requiresLongRunningProcess: Bool? = nil,
        readyEvents: [String]? = nil,
        finalEvents: [String]? = nil,
        terminationSignals: [String]? = nil
    ) {
        self.command = command
        self.args = args
        self.category = category ?? TKCommandRecoveryCommand.category(forRootCommand: command) ?? "plan"
        let argv = ["triton", command] + args
        let resolvedRequiresLongRunning = requiresLongRunningProcess ?? Self.defaultRequiresLongRunningProcess(for: argv)
        self.requiresLongRunningProcess = resolvedRequiresLongRunning
        self.readyEvents = readyEvents ?? Self.defaultReadyEvents(for: argv)
        self.finalEvents = finalEvents ?? Self.defaultFinalEvents(for: argv)
        self.terminationSignals = terminationSignals ?? Self.defaultTerminationSignals(for: argv)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let command = try container.decode(String.self, forKey: .command)
        self.command = command
        self.args = try container.decode([String].self, forKey: .args)
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ??
            TKCommandRecoveryCommand.category(forRootCommand: command) ??
            "plan"
        let argv = ["triton", command] + args
        self.requiresLongRunningProcess = try container.decodeIfPresent(Bool.self, forKey: .requiresLongRunningProcess) ??
            Self.defaultRequiresLongRunningProcess(for: argv)
        self.readyEvents = try container.decodeIfPresent([String].self, forKey: .readyEvents) ??
            Self.defaultReadyEvents(for: argv)
        self.finalEvents = try container.decodeIfPresent([String].self, forKey: .finalEvents) ??
            Self.defaultFinalEvents(for: argv)
        self.terminationSignals = try container.decodeIfPresent([String].self, forKey: .terminationSignals) ??
            Self.defaultTerminationSignals(for: argv)
    }

    public static func fromTritonArgv(_ argv: [String]) -> TKCLINextAction? {
        guard argv.count >= 2, argv[0] == "triton" else {
            return nil
        }
        let command = argv[1]
        let args = Array(argv.dropFirst(2))
        return TKCLINextAction(
            command: command,
            args: args
        )
    }

    private static func defaultRequiresLongRunningProcess(for argv: [String]) -> Bool {
        Array(argv.prefix(2)) == ["triton", "serve"] ||
            Array(argv.prefix(4)) == ["triton", "device", "proxy", "serve"]
    }

    private static func defaultReadyEvents(for argv: [String]) -> [String] {
        if Array(argv.prefix(4)) == ["triton", "device", "proxy", "serve"] {
            return ["proxy.serve.ready"]
        }
        return []
    }

    private static func defaultFinalEvents(for argv: [String]) -> [String] {
        if Array(argv.prefix(4)) == ["triton", "device", "proxy", "serve"] {
            return ["proxy.serve.summary"]
        }
        return []
    }

    private static func defaultTerminationSignals(for argv: [String]) -> [String] {
        if Array(argv.prefix(2)) == ["triton", "serve"] ||
            Array(argv.prefix(4)) == ["triton", "device", "proxy", "serve"] {
            return ["sigint", "sigterm"]
        }
        return []
    }
}

public struct TKWorkflowPlanStep: Codable, Equatable {
    public let id: String
    public let title: String
    public let command: String
    public let argv: [String]
    public let category: String
    public let workflowCategories: [String]
    public let requiresServer: Bool
    public let requiresTarget: Bool
    public let when: String
    public let expected: String
    public let requires: [String]
    public let expectedArtifacts: [String]
    public let stopConditions: [String]
    public let requiresLongRunningProcess: Bool
    public let readyEvents: [String]
    public let finalEvents: [String]
    public let terminationSignals: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case command
        case argv
        case category
        case workflowCategories
        case requiresServer
        case requiresTarget
        case when
        case expected
        case requires
        case expectedArtifacts
        case stopConditions
        case requiresLongRunningProcess
        case readyEvents
        case finalEvents
        case terminationSignals
    }

    public init(
        id: String,
        title: String,
        command: String,
        argv: [String]? = nil,
        category: String? = nil,
        workflowCategories: [String]? = nil,
        requiresServer: Bool,
        requiresTarget: Bool,
        when: String,
        expected: String,
        requires: [String]? = nil,
        expectedArtifacts: [String]? = nil,
        stopConditions: [String]? = nil,
        requiresLongRunningProcess: Bool? = nil,
        readyEvents: [String]? = nil,
        finalEvents: [String]? = nil,
        terminationSignals: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.command = command
        let resolvedArgv = argv ?? Self.defaultArgv(for: command)
        self.argv = resolvedArgv
        self.category = category ?? Self.category(for: command)
        self.workflowCategories = workflowCategories ?? Self.defaultWorkflowCategories(for: command)
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.when = when
        self.expected = expected
        self.requires = requires ?? Self.defaultRequires(requiresServer: requiresServer, requiresTarget: requiresTarget)
        self.expectedArtifacts = expectedArtifacts ?? Self.defaultExpectedArtifacts(for: command)
        self.stopConditions = stopConditions ?? Self.defaultStopConditions(
            for: command,
            requiresServer: requiresServer,
            requiresTarget: requiresTarget
        )
        self.requiresLongRunningProcess = requiresLongRunningProcess ?? Self.defaultRequiresLongRunningProcess(for: resolvedArgv)
        self.readyEvents = readyEvents ?? Self.defaultReadyEvents(for: resolvedArgv)
        self.finalEvents = finalEvents ?? Self.defaultFinalEvents(for: resolvedArgv)
        self.terminationSignals = terminationSignals ?? Self.defaultTerminationSignals(for: resolvedArgv)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let command = try container.decode(String.self, forKey: .command)
        let requiresServer = try container.decode(Bool.self, forKey: .requiresServer)
        let requiresTarget = try container.decode(Bool.self, forKey: .requiresTarget)
        self.id = id
        self.title = title
        self.command = command
        let resolvedArgv = try container.decodeIfPresent([String].self, forKey: .argv) ?? Self.defaultArgv(for: command)
        self.argv = resolvedArgv
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? Self.category(for: command)
        self.workflowCategories = try container.decodeIfPresent([String].self, forKey: .workflowCategories)
            ?? Self.defaultWorkflowCategories(for: command)
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.when = try container.decode(String.self, forKey: .when)
        self.expected = try container.decode(String.self, forKey: .expected)
        self.requires = try container.decodeIfPresent([String].self, forKey: .requires) ??
            Self.defaultRequires(requiresServer: requiresServer, requiresTarget: requiresTarget)
        self.expectedArtifacts = try container.decodeIfPresent([String].self, forKey: .expectedArtifacts) ??
            Self.defaultExpectedArtifacts(for: command)
        self.stopConditions = try container.decodeIfPresent([String].self, forKey: .stopConditions) ??
            Self.defaultStopConditions(for: command, requiresServer: requiresServer, requiresTarget: requiresTarget)
        self.requiresLongRunningProcess = try container.decodeIfPresent(Bool.self, forKey: .requiresLongRunningProcess) ??
            Self.defaultRequiresLongRunningProcess(for: resolvedArgv)
        self.readyEvents = try container.decodeIfPresent([String].self, forKey: .readyEvents) ??
            Self.defaultReadyEvents(for: resolvedArgv)
        self.finalEvents = try container.decodeIfPresent([String].self, forKey: .finalEvents) ??
            Self.defaultFinalEvents(for: resolvedArgv)
        self.terminationSignals = try container.decodeIfPresent([String].self, forKey: .terminationSignals) ??
            Self.defaultTerminationSignals(for: resolvedArgv)
    }

    private static func defaultRequiresLongRunningProcess(for argv: [String]) -> Bool {
        Array(argv.prefix(2)) == ["triton", "serve"] ||
            Array(argv.prefix(4)) == ["triton", "device", "proxy", "serve"]
    }

    private static func defaultReadyEvents(for argv: [String]) -> [String] {
        if Array(argv.prefix(4)) == ["triton", "device", "proxy", "serve"] {
            return ["proxy.serve.ready"]
        }
        return []
    }

    private static func defaultFinalEvents(for argv: [String]) -> [String] {
        if Array(argv.prefix(4)) == ["triton", "device", "proxy", "serve"] {
            return ["proxy.serve.summary"]
        }
        return []
    }

    private static func defaultTerminationSignals(for argv: [String]) -> [String] {
        defaultRequiresLongRunningProcess(for: argv) ? ["sigint", "sigterm"] : []
    }

    private static func category(for command: String) -> String {
        guard let root = TKCommandRecoveryCommand.rootCommand(in: command),
              let category = TKCommandRecoveryCommand.category(forRootCommand: root) else {
            return "plan"
        }
        return category
    }

    private static func defaultArgv(for command: String) -> [String] {
        let tokens = shellTokens(in: command)
        return tokens.isEmpty ? [command] : tokens
    }

    private static func defaultWorkflowCategories(for command: String) -> [String] {
        let taxonomy = [
            "action", "app", "assert", "evidence", "observe", "project",
            "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
        ]

        let tokens = shellTokens(in: command)
        guard let tritonIndex = tokens.firstIndex(of: "triton"), tokens.count > tritonIndex + 1 else {
            return []
        }

        let root = tokens[tritonIndex + 1]
        let subcommand = tokens.count > tritonIndex + 2 ? tokens[tritonIndex + 2] : nil
        let allWorkflows = Set(taxonomy)
        let values: Set<String>

        switch (root, subcommand) {
        case ("serve", _):
            values = ["app", "observe", "action", "assert", "evidence", "replay", "route", "smoke", "webview-check"]
        case ("target", _):
            values = ["target", "app", "runtime", "observe", "action", "assert", "evidence", "smoke"]
        case ("xcode", "run"):
            values = ["project", "xcode", "target", "app", "runtime", "evidence"]
        case ("xcode", _):
            values = ["project", "xcode", "evidence"]
        case ("app", _):
            values = ["target", "app", "assert", "evidence"]
        case ("assert", _):
            values = ["assert", "evidence"]
        case ("runtime", _):
            values = ["app", "runtime", "observe", "action", "assert", "evidence"]
        case ("state", _), ("snapshot", _):
            values = ["app", "runtime", "observe", "action", "assert", "evidence"]
        case ("webview", _):
            values = ["observe", "route", "assert", "evidence", "webview-check"]
        case ("route", _):
            values = ["route", "assert", "evidence", "webview-check"]
        case ("smoke", _):
            values = ["smoke", "target", "app", "assert", "evidence"]
        case ("evidence", _), ("capture", _), ("export", _):
            values = ["evidence", "replay"]
        case ("plan", _):
            values = allWorkflows
        case ("geometry", _), ("ax", _), ("hit", _), ("wait", _), ("screenshot", _), ("list", _), ("inspect", _):
            values = ["observe", "action", "assert", "evidence"]
        case ("input", _), ("tap", _), ("swipe", _), ("type", _), ("paste", _), ("clear", _), ("press", _):
            values = ["action", "assert", "evidence"]
        case ("doctor", _), ("status", _), ("capabilities", _), ("schema", _):
            values = allWorkflows
        default:
            values = []
        }

        return taxonomy.filter { values.contains($0) }
    }

    private static func defaultRequires(requiresServer: Bool, requiresTarget: Bool) -> [String] {
        var values = ["cli.available"]
        if requiresServer {
            values.append("server.reachable")
        }
        if requiresTarget {
            values.append("target.ready")
            values.append("runtime.connected")
        }
        return unique(values)
    }

    fileprivate static func defaultExpectedArtifacts(for command: String) -> [String] {
        let root = TKCommandRecoveryCommand.rootCommand(in: command) ?? "plan"
        var values = ["stdout-json"]

        switch root {
        case "assert":
            values.append("assertion-result")
        case "capture", "evidence", "export":
            values.append("evidence-bundle")
        case "coverage":
            values.append("coverage-report")
        case "route":
            values.append("route-assertion")
        case "replay":
            values.append("replay-summary")
        case "screenshot":
            values.append("screenshot")
        case "smoke":
            values.append("smoke-summary")
            values.append("evidence-bundle")
        case "target":
            values.append("target-resolution")
        case "wait":
            values.append("wait-result")
        case "webview":
            values.append("webview-json")
        case "xcode":
            values.append("xcode-log")
        case "xcresult":
            values.append("xcresult-summary")
        case "xctrace":
            values.append("trace")
        default:
            break
        }

        return unique(values)
    }

    private static func defaultStopConditions(for command: String, requiresServer: Bool, requiresTarget: Bool) -> [String] {
        let root = TKCommandRecoveryCommand.rootCommand(in: command) ?? "plan"
        var values = ["command.failed"]
        if requiresServer {
            values.append("server.unavailable")
        }
        if requiresTarget {
            values.append("target.unavailable")
        }

        switch root {
        case "assert", "route":
            values.append("assertion.failed")
        case "capture", "evidence", "export", "screenshot", "xcresult", "xctrace", "coverage":
            values.append("artifact.write-failed")
        case "replay", "smoke":
            values.append("step.failed")
        case "wait":
            values.append("timeout")
        default:
            break
        }

        return unique(values)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func shellTokens(in command: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingleQuote = false
        var iterator = command.makeIterator()

        while let character = iterator.next() {
            if inSingleQuote {
                if character == "'" {
                    inSingleQuote = false
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "'" {
                inSingleQuote = true
                continue
            }

            if character == "\\" {
                if let next = iterator.next() {
                    current.append(next)
                } else {
                    current.append(character)
                }
                continue
            }

            if character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll(keepingCapacity: true)
                }
                continue
            }

            current.append(character)
        }

        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}

public struct TKWorkflowPlanResponse: Codable, Equatable {
    public let ok: Bool
    public let serverReachable: Bool
    public let connected: Bool
    public let runtime: String
    public let surface: String
    public let mode: String
    public let goal: String?
    public let nextStep: String
    public let nextWorkflows: [String]
    public let primaryWorkflowCategory: String?
    public let primaryExpectedArtifact: String?
    public let primaryNextAction: TKCLINextAction?
    public let primaryNextActionSource: String?
    public let steps: [TKWorkflowPlanStep]
    public let error: TKCLIErrorDetail?

    enum CodingKeys: String, CodingKey {
        case ok
        case serverReachable
        case connected
        case runtime
        case surface
        case mode
        case goal
        case nextStep
        case nextWorkflows
        case primaryWorkflowCategory
        case primaryExpectedArtifact
        case primaryNextAction
        case primaryNextActionSource
        case steps
        case error
    }

    public init(
        ok: Bool,
        serverReachable: Bool,
        connected: Bool,
        runtime: String,
        surface: String = "plan",
        mode: String? = nil,
        goal: String? = nil,
        nextStep: String,
        nextWorkflows: [String]? = nil,
        primaryWorkflowCategory: String? = nil,
        primaryExpectedArtifact: String? = nil,
        primaryNextAction: TKCLINextAction? = nil,
        primaryNextActionSource: String? = nil,
        steps: [TKWorkflowPlanStep],
        error: TKCLIErrorDetail? = nil
    ) {
        self.ok = ok
        self.serverReachable = serverReachable
        self.connected = connected
        self.runtime = runtime
        self.surface = surface
        self.mode = mode ?? Self.defaultMode(for: goal)
        self.goal = goal
        self.nextStep = nextStep
        self.nextWorkflows = nextWorkflows ?? Self.defaultNextWorkflows(for: goal, nextStep: nextStep)
        let primarySelection = Self.defaultPrimarySelection(
            goal: goal,
            nextStep: nextStep,
            steps: steps,
            error: error,
            preferredWorkflowCategory: primaryWorkflowCategory,
            preferredExpectedArtifact: primaryExpectedArtifact,
            preferredAction: primaryNextAction,
            preferredSource: primaryNextActionSource
        )
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryExpectedArtifact = primarySelection.expectedArtifact
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.steps = steps
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.serverReachable = try container.decode(Bool.self, forKey: .serverReachable)
        self.connected = try container.decode(Bool.self, forKey: .connected)
        self.runtime = try container.decode(String.self, forKey: .runtime)
        self.surface = try container.decodeIfPresent(String.self, forKey: .surface) ?? "plan"
        self.goal = try container.decodeIfPresent(String.self, forKey: .goal)
        self.mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? Self.defaultMode(for: goal)
        let decodedNextStep = try container.decode(String.self, forKey: .nextStep)
        self.nextStep = decodedNextStep
        self.nextWorkflows = try container.decodeIfPresent([String].self, forKey: .nextWorkflows)
            ?? Self.defaultNextWorkflows(for: goal, nextStep: decodedNextStep)
        let decodedSteps = try container.decode([TKWorkflowPlanStep].self, forKey: .steps)
        self.steps = decodedSteps
        let decodedError = try container.decodeIfPresent(TKCLIErrorDetail.self, forKey: .error)
        let primarySelection = Self.defaultPrimarySelection(
            goal: self.goal,
            nextStep: decodedNextStep,
            steps: decodedSteps,
            error: decodedError,
            preferredWorkflowCategory: try container.decodeIfPresent(String.self, forKey: .primaryWorkflowCategory),
            preferredExpectedArtifact: try container.decodeIfPresent(String.self, forKey: .primaryExpectedArtifact),
            preferredAction: try container.decodeIfPresent(TKCLINextAction.self, forKey: .primaryNextAction),
            preferredSource: try container.decodeIfPresent(String.self, forKey: .primaryNextActionSource)
        )
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryExpectedArtifact = primarySelection.expectedArtifact
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.error = decodedError
    }

    private static func defaultMode(for goal: String?) -> String {
        guard let goal, !goal.isEmpty, goal != "general" else {
            return "bootstrap"
        }
        return "task"
    }

    private static func defaultNextWorkflows(for goal: String?, nextStep: String) -> [String] {
        let taxonomy = [
            "action", "app", "assert", "evidence", "observe", "project",
            "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
        ]

        let values: Set<String>
        switch goal {
        case nil, "", "general":
            switch nextStep {
            case "start-server":
                values = ["app", "observe", "action", "assert", "evidence", "replay", "route", "smoke", "webview-check"]
            case "connect-target":
                values = ["target", "app", "runtime", "observe", "action", "assert", "evidence", "smoke", "route", "webview-check"]
            case "geometry", "ax", "wait", "hit", "input", "screenshot", "archive":
                values = ["observe", "action", "assert", "evidence"]
            default:
                values = []
            }
        case "ios-smoke":
            values = ["smoke", "target", "app", "assert", "evidence"]
        case "open-url":
            values = ["target", "app", "assert", "evidence"]
        case "webview-check":
            values = ["observe", "route", "assert", "evidence", "webview-check"]
        case "network-proxy":
            values = ["target", "evidence"]
        default:
            values = []
        }

        return taxonomy.filter { values.contains($0) }
    }

    private static func defaultPrimaryNextAction(for goal: String?, nextStep: String) -> TKCLINextAction? {
        switch nextStep {
        case "start-server":
            return TKCLINextAction(command: "serve", args: [], requiresLongRunningProcess: true)
        case "inspect-schema":
            return TKCLINextAction(command: "schema", args: ["--json"])
        case "connect-target", "target-list":
            return TKCLINextAction(command: "target", args: ["list", "--json"])
        case "target-resolve":
            return TKCLINextAction(command: "target", args: ["resolve", "<selector>", "--json"])
        case "target-use":
            return TKCLINextAction(command: "target", args: ["use", "<selector>", "--json"])
        case "target-wait-ready":
            return TKCLINextAction(command: "target", args: ["wait-ready", "<selector>", "--json"])
        case "geometry":
            return TKCLINextAction(command: "geometry", args: ["--json"])
        case "ax":
            return TKCLINextAction(command: "ax", args: ["--json"])
        case "wait", "wait-text":
            return TKCLINextAction(command: "wait", args: ["--text", "<text>", "--json"])
        case "hit":
            return TKCLINextAction(command: "hit", args: ["--json"])
        case "input":
            return TKCLINextAction(command: "input", args: ["--json", "--summary", "--strict"])
        case "screenshot":
            return TKCLINextAction(command: "screenshot", args: ["--json"])
        case "archive":
            return TKCLINextAction(command: "export", args: ["--format", "archive", "--json"])
        case "app-open-url":
            return TKCLINextAction(command: "app", args: ["open-url", "<url>", "--json"])
        case "webview-current":
            return TKCLINextAction(command: "webview", args: ["current", "--json"])
        case "route-assert-current-url":
            return TKCLINextAction(command: "route", args: ["assert-current-url", "<expected-url>", "--json"])
        case "ios-smoke":
            return TKCLINextAction(command: "smoke", args: ["ios", "--json"])
        default:
            guard goal == "webview-check" else {
                return nil
            }
            return TKCLINextAction(command: "webview", args: ["current", "--json"])
        }
    }

    private static func defaultPrimarySelection(
        goal: String?,
        nextStep: String,
        steps: [TKWorkflowPlanStep],
        error: TKCLIErrorDetail?,
        preferredWorkflowCategory: String?,
        preferredExpectedArtifact: String?,
        preferredAction: TKCLINextAction?,
        preferredSource: String?
    ) -> (workflowCategory: String?, expectedArtifact: String?, nextAction: TKCLINextAction?, source: String?) {
        if let preferredAction {
            return (
                preferredWorkflowCategory ?? workflowCategory(for: preferredAction, in: steps),
                preferredExpectedArtifact ?? expectedArtifact(for: preferredAction, in: steps),
                preferredAction,
                preferredSource ?? "explicit"
            )
        }
        if let nextStepAction = steps.first(where: { $0.id == nextStep }).flatMap({ TKCLINextAction.fromTritonArgv($0.argv) }) {
            return (
                steps.first(where: { $0.id == nextStep }).flatMap { primaryWorkflowCategory(for: $0.workflowCategories) },
                steps.first(where: { $0.id == nextStep })?.expectedArtifacts.first,
                nextStepAction,
                "next-step-step"
            )
        }
        if let firstStepAction = steps.first.flatMap({ TKCLINextAction.fromTritonArgv($0.argv) }) {
            return (
                steps.first.flatMap { primaryWorkflowCategory(for: $0.workflowCategories) },
                steps.first?.expectedArtifacts.first,
                firstStepAction,
                "first-step"
            )
        }
        if let defaultAction = Self.defaultPrimaryNextAction(for: goal, nextStep: nextStep) {
            return (
                preferredWorkflowCategory ?? primaryWorkflowCategory(for: Self.defaultNextWorkflows(for: goal, nextStep: nextStep)),
                preferredExpectedArtifact ?? Self.defaultExpectedArtifacts(for: defaultAction).first,
                defaultAction,
                "default-next-step"
            )
        }
        if let errorAction = error?.nextAction {
            return (
                workflowCategory(for: errorAction, in: steps) ?? preferredWorkflowCategory,
                expectedArtifact(for: errorAction, in: steps) ?? preferredExpectedArtifact,
                errorAction,
                "error"
            )
        }
        return (preferredWorkflowCategory, preferredExpectedArtifact, nil, preferredSource)
    }

    private static func workflowCategory(for action: TKCLINextAction, in steps: [TKWorkflowPlanStep]) -> String? {
        steps.first(where: { TKCLINextAction.fromTritonArgv($0.argv) == action })
            .flatMap { primaryWorkflowCategory(for: $0.workflowCategories) }
    }

    private static func expectedArtifact(for action: TKCLINextAction, in steps: [TKWorkflowPlanStep]) -> String? {
        steps.first(where: { TKCLINextAction.fromTritonArgv($0.argv) == action })?.expectedArtifacts.first
    }

    private static func primaryWorkflowCategory(for categories: [String]) -> String? {
        let priority = [
            "app", "target", "runtime", "observe", "action", "assert",
            "evidence", "smoke", "route", "replay", "webview-check",
            "project", "xcode",
        ]
        let categorySet = Set(categories)
        if let preferred = priority.first(where: { categorySet.contains($0) }) {
            return preferred
        }
        return categories.first
    }

    private static func defaultExpectedArtifacts(for action: TKCLINextAction) -> [String] {
        let command = ([action.command] + action.args).joined(separator: " ")
        return TKWorkflowPlanStep.defaultExpectedArtifacts(for: command)
    }
}
