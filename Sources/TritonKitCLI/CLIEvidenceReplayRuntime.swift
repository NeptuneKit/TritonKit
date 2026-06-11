import ArgumentParser
import Darwin
import Foundation
import TritonKit
import TritonKitShared

func readReplayPlan(from path: String) throws -> TKReplayPlan {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let plan = try JSONDecoder().decode(TKReplayPlan.self, from: data)
    guard plan.schemaVersion == 1 else {
        throw RuntimeError("Unsupported replay plan schemaVersion: \(plan.schemaVersion)")
    }
    guard !plan.steps.isEmpty else {
        throw RuntimeError("Replay plan must contain at least one step")
    }
    return plan
}

func parseReplayVariables(_ assignments: [String]) throws -> [String: String] {
    var result: [String: String] = [:]
    for assignment in assignments {
        guard let equals = assignment.firstIndex(of: "=") else {
            throw RuntimeError("Invalid --var assignment: \(assignment)")
        }
        let key = String(assignment[..<equals])
        let value = String(assignment[assignment.index(after: equals)...])
        guard !key.isEmpty else {
            throw RuntimeError("Invalid --var assignment with empty key")
        }
        if key.hasSuffix("-env") {
            let variableName = String(key.dropLast(4))
            guard !variableName.isEmpty else {
                throw RuntimeError("Invalid --var env assignment with empty key")
            }
            guard let envValue = ProcessInfo.processInfo.environment[value] else {
                throw RuntimeError("Environment variable is not set for replay variable \(variableName): \(value)")
            }
            result[variableName] = envValue
        } else {
            result[key] = value
        }
    }
    return result
}

func runReplayPlan(
    _ plan: TKReplayPlan,
    variables: [String: String],
    dryRun: Bool,
    target: String,
    host: String,
    port: Int
) async throws -> TKReplayResult {
    let start = Date()
    var steps: [TKReplayStepResult] = []
    var failedStepIndex: Int?
    let commands = try plan.steps.enumerated().map { offset, step in
        try replayCommand(for: step, plan: plan, index: offset + 1, variables: variables)
    }
    var client = TritonKitHTTPClient(host: host, port: port)

    if !dryRun {
        let resolved = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
        client = resolved.client
    }

    for (offset, step) in plan.steps.enumerated() {
        let index = offset + 1
        let command = commands[offset]
        if dryRun {
            steps.append(TKReplayStepResult(
                index: index,
                action: step.action.rawValue,
                name: step.name ?? step.id,
                ok: true,
                dryRun: true,
                elapsedMs: 0,
                command: command,
                message: "dry-run"
            ))
            continue
        }

        let stepStart = Date()
        do {
            let result = try await executeReplayStep(
                step,
                plan: plan,
                index: index,
                variables: variables,
                target: target,
                host: host,
                port: port,
                client: client,
                command: command,
                startedAt: stepStart
            )
            steps.append(result)
            if !result.ok {
                failedStepIndex = index
                break
            }
        } catch {
            failedStepIndex = index
            steps.append(replayFailureStepResult(
                step: step,
                index: index,
                command: command,
                error: error,
                startedAt: stepStart,
                host: host,
                port: port
            ))
            break
        }
    }

    return TKReplayResult(
        ok: failedStepIndex == nil,
        dryRun: dryRun,
        planName: plan.name,
        stepCount: plan.steps.count,
        executedCount: steps.count,
        failedStepIndex: failedStepIndex,
        failureCode: replayFailureCode(steps: steps, failedStepIndex: failedStepIndex),
        failureError: replayFailureError(steps: steps, failedStepIndex: failedStepIndex),
        failureWorkflowCategories: replayFailureWorkflowCategories(steps: steps, failedStepIndex: failedStepIndex),
        failureRecoveryCategories: replayFailureRecoveryCategories(steps: steps, failedStepIndex: failedStepIndex),
        failurePrimaryArtifacts: replayFailurePrimaryArtifacts(steps: steps, failedStepIndex: failedStepIndex),
        elapsedMs: elapsedMilliseconds(since: start),
        steps: steps,
        suggestedCommands: replaySuggestedCommands(
            steps: steps,
            failedStepIndex: failedStepIndex
        ),
        recoveryCommands: replayRecoveryCommands(
            steps: steps,
            failedStepIndex: failedStepIndex
        )
    )
}

func replayFailureWorkflowCategories(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [String] {
    guard let failedStepIndex else { return [] }
    return steps.first { $0.index == failedStepIndex }?.workflowCategories ?? []
}

func replayFailureCode(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> String? {
    guard let failedStepIndex else { return nil }
    return steps.first { $0.index == failedStepIndex }?.failureCode
}

func replayFailureError(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> TKCLIErrorDetail? {
    guard let failedStepIndex else { return nil }
    return steps.first { $0.index == failedStepIndex }?.error
}

func replayFailureRecoveryCategories(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [String] {
    guard let failureCode = replayFailureCode(steps: steps, failedStepIndex: failedStepIndex) else { return [] }
    let familyCategories = TKCommandRecoveryCommand.recoveryCategories(forFailureCode: failureCode)
    let recoveryCategories = replayRecoveryCommands(steps: steps, failedStepIndex: failedStepIndex).map(\.category)
    let nextActionCategory = replayFailureError(steps: steps, failedStepIndex: failedStepIndex)?.nextAction?.category

    if nextActionCategory == nil {
        return familyCategories
    }

    var categories: [String] = []
    var seen = Set<String>()

    func append(_ category: String?) {
        guard let category, !seen.contains(category) else { return }
        seen.insert(category)
        categories.append(category)
    }

    append(nextActionCategory)
    for category in recoveryCategories {
        append(category)
    }
    for category in familyCategories {
        append(category)
    }
    return categories
}

func replayFailurePrimaryArtifacts(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [TKEvidenceArtifactSummary] {
    TKReplayResult(
        ok: failedStepIndex == nil,
        dryRun: false,
        planName: nil,
        stepCount: steps.count,
        executedCount: steps.count,
        failedStepIndex: failedStepIndex,
        elapsedMs: 0,
        steps: steps
    ).failurePrimaryArtifacts
}

func replaySuggestedCommands(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [String] {
    guard let failedStepIndex,
          let failedStep = steps.first(where: { $0.index == failedStepIndex }) else { return [] }

    var commands: [String] = []

    if let nextActionCommand = replayFailureNextActionCommandString(steps: steps, failedStepIndex: failedStepIndex) {
        commands.append(nextActionCommand)
    }

    if let query = failedStep.wait?.query, !query.isEmpty {
        commands.append("triton find \(shellQuotedEvidencePath(query)) --all --json")
    }
    if failedStep.wait != nil {
        commands.append("triton snapshot --json")
    }
    if failedStep.input != nil {
        commands.append("triton snapshot --json")
        commands.append("triton screenshot --json")
    }
    if let evidence = failedStep.evidence {
        commands.append("triton evidence summary \(shellQuotedEvidencePath(evidence.output)) --json")
        commands.append("triton evidence inspect \(shellQuotedEvidencePath(evidence.output)) --json")
        commands.append("triton evidence redact \(shellQuotedEvidencePath(evidence.output)) --output \(shellQuotedEvidencePath(evidence.output + "-redacted")) --json")
    }
    if failedStep.evidence == nil,
       let recentEvidence = steps.reversed().compactMap(\.evidence).first {
        commands.append("triton evidence summary \(shellQuotedEvidencePath(recentEvidence.output)) --json")
        commands.append("triton evidence inspect \(shellQuotedEvidencePath(recentEvidence.output)) --json")
    }

    var unique: [String] = []
    var seen = Set<String>()
    for command in commands where !seen.contains(command) {
        seen.insert(command)
        unique.append(command)
    }
    return Array(unique.prefix(5))
}

func replayRecoveryCommands(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> [TKCommandRecoveryCommand] {
    replaySuggestedCommands(steps: steps, failedStepIndex: failedStepIndex)
        .compactMap(TKCommandRecoveryCommand.init(commandString:))
}

func replayFailureNextActionCommandString(
    steps: [TKReplayStepResult],
    failedStepIndex: Int?
) -> String? {
    guard let nextAction = replayFailureError(steps: steps, failedStepIndex: failedStepIndex)?.nextAction else {
        return nil
    }
    return (["triton", nextAction.command] + nextAction.args).joined(separator: " ")
}

func replayFailureStepResult(
    step: TKReplayPlanStep,
    index: Int,
    command: [String],
    error: Error,
    startedAt: Date,
    host: String,
    port: Int
) -> TKReplayStepResult {
    let detail = replayFailureDetail(for: step, error: error, host: host, port: port)
    return TKReplayStepResult(
        index: index,
        action: step.action.rawValue,
        name: step.name ?? step.id,
        ok: false,
        dryRun: false,
        elapsedMs: elapsedMilliseconds(since: startedAt),
        command: command,
        failureCode: detail.code,
        error: detail,
        message: detail.message
    )
}

func replayFailureDetail(
    for step: TKReplayPlanStep,
    error: Error,
    host: String,
    port: Int
) -> TKCLIErrorDetail {
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return response.error
    }
    if let timeoutError = error as? RuntimeRequestTimeoutError {
        return TKCLIErrorDetail(
            code: "timeout",
            message: timeoutError.description,
            endpoint: endpointURL(replayEndpoint(for: step.action), host: host, port: port),
            hint: "Run `triton snapshot --json` or retry the replay step after the runtime responds again."
        )
    }
    if isReplayArtifactWriteFailure(step: step, error: error) {
        return TKCLIErrorDetail(
            code: "artifact_write_failed",
            message: "\(error)",
            hint: "Check the replay output path, parent directory existence, and write permissions."
        )
    }
    return cliErrorDetail(
        for: error,
        endpoint: replayEndpoint(for: step.action),
        host: host,
        port: port
    )
}

func replayEndpoint(for action: TKReplayAction) -> String {
    switch action {
    case .tap, .paste, .type, .clear:
        return "/runtime/input"
    case .wait:
        return "/runtime/wait"
    case .screenshot:
        return "/runtime/screenshot"
    case .evidence:
        return "/evidence/capture"
    case .proxyServe, .proxyStart, .proxyExport, .proxyStop:
        return "/device/proxy"
    }
}

func isReplayArtifactWriteFailure(step: TKReplayPlanStep, error: Error) -> Bool {
    guard step.action == .screenshot || step.action == .evidence || step.action == .proxyServe || step.action == .proxyExport else {
        return false
    }
    guard let cocoaError = error as? CocoaError else { return false }
    switch cocoaError.code {
    case .fileNoSuchFile, .fileWriteNoPermission, .fileWriteInvalidFileName, .fileWriteFileExists, .fileWriteOutOfSpace:
        return true
    default:
        return false
    }
}

func executeReplayStep(
    _ step: TKReplayPlanStep,
    plan: TKReplayPlan,
    index: Int,
    variables: [String: String],
    target: String,
    host: String,
    port: Int,
    client: TritonKitHTTPClient,
    command: [String],
    startedAt: Date
) async throws -> TKReplayStepResult {
    switch step.action {
    case .tap:
        let request = try await replayTapRequest(step, variables: variables, client: client)
        let input = try await executeInputRequest(request, client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: input.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, input: input, host: host, port: port),
            message: input.message,
            input: input
        )
    case .paste, .type, .clear:
        let (request, redactedValue) = try replayTextInputRequest(step, variables: variables)
        let input = try await executeInputRequest(request, client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: input.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, input: input, host: host, port: port),
            message: input.message,
            redactedValue: redactedValue,
            input: input
        )
    case .wait:
        let wait = try await performWait(replayWaitRequest(step, variables: variables), client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: wait.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, wait: wait, host: host, port: port),
            message: wait.ok ? "matched" : "timed out",
            wait: wait
        )
    case .screenshot:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).png",
            variables: variables
        )
        let data = try await client.request(type: "screenshot")
        let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: data)
        let imageData = try await screenshotImageData(screenshot, client: client)
        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try imageData.write(to: outputURL, options: .atomic)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: true,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            message: "screenshot captured",
            file: TKReplayFileArtifact(path: outputURL.path, bytes: imageData.count, contentType: "image/png")
        )
    case .evidence:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).tritonevidence",
            variables: variables
        )
        let proxySessionPath = try step.proxySession.map {
            try TKReplaySubstituteVariables($0, variables: variables)
        }
        let includes = try parseEvidenceIncludes(step.include ?? "status,list,version,hierarchy,ax,screenshot")
        let manifest = try await captureEvidenceBundle(
            output: output,
            includes: includes,
            name: step.name ?? plan.name,
            note: step.note,
            target: target,
            host: host,
            port: port,
            refresh: step.refresh ?? true,
            proxySessionPath: proxySessionPath
        )
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: manifest.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            error: replayStepError(for: step, evidence: manifest, host: host, port: port),
            message: "evidence captured",
            evidence: manifest
        )
    case .proxyServe, .proxyStart, .proxyExport, .proxyStop:
        let detail = TKCLIErrorDetail(
            code: "unsupported_capability",
            message: "Replay \(step.action.rawValue) is dry-run only; execute the emitted `triton device proxy` command explicitly after policy review.",
            endpoint: "/device/proxy",
            hint: "Run `triton replay <file.tritonplan> --dry-run --json`, inspect argv, then execute the individual proxy command only when the proxy change is intentional.",
            nextAction: TKCLINextAction(
                command: "replay",
                args: ["<file.tritonplan>", "--dry-run", "--json"],
                category: "replay"
            )
        )
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: false,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            failureCode: detail.code,
            error: detail,
            message: detail.message
        )
    }
}

func replayStepError(
    for step: TKReplayPlanStep,
    input: TKInputResult? = nil,
    wait: TKWaitResult? = nil,
    evidence: TKEvidenceManifest? = nil,
    host: String,
    port: Int
) -> TKCLIErrorDetail? {
    if let input, !input.ok {
        return TKCLIErrorDetail(
            code: "action_failed",
            message: input.message ?? "Replay input step failed",
            endpoint: endpointURL(replayEndpoint(for: step.action), host: host, port: port),
            hint: "Run `triton input --json --summary --strict` or inspect the current UI with `triton snapshot --json`."
        )
    }
    if let wait, !wait.ok {
        let message: String
        if wait.timedOut {
            if let query = wait.query, !query.isEmpty {
                message = "Timed out waiting for \(wait.condition) '\(query)'"
            } else {
                message = "Timed out waiting for \(wait.condition)"
            }
        } else {
            message = "Replay wait step failed"
        }
        return TKCLIErrorDetail(
            code: wait.timedOut ? "timeout" : "request_failed",
            message: message,
            endpoint: endpointURL(replayEndpoint(for: step.action), host: host, port: port),
            hint: "Run `triton wait --format json` with a narrower condition or inspect the current UI with `triton snapshot --json`."
        )
    }
    if let evidence, !evidence.ok {
        return TKCLIErrorDetail(
            code: "request_failed",
            message: "Replay evidence step reported ok=false for \(evidence.output)",
            hint: "Inspect the evidence output path and rerun `triton evidence summary \(shellQuotedEvidencePath(evidence.output)) --json` if artifacts were partially written."
        )
    }
    return nil
}

func replayTapRequest(
    _ step: TKReplayPlanStep,
    variables: [String: String],
    client: TritonKitHTTPClient
) async throws -> TKInputRequest {
    let selectorCount = [
        step.text != nil,
        step.oid != nil,
        step.x != nil || step.y != nil,
        step.axOID != nil,
        step.axLabel != nil,
    ].filter { $0 }.count
    guard selectorCount == 1 else {
        throw RuntimeError("Replay tap step requires exactly one selector: text, oid, x/y, axOID, or axLabel")
    }
    if (step.x == nil) != (step.y == nil) {
        throw RuntimeError("Replay tap step requires x and y together")
    }
    if let text = step.text {
        let query = try TKReplaySubstituteVariables(text, variables: variables)
        return try await resolveTapTarget(
            query,
            client: client,
            width: step.width,
            height: step.height,
            duration: step.duration
        ).request
    }
    if step.axOID != nil || step.axLabel != nil {
        let data = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
        let label = try step.axLabel.map { try TKReplaySubstituteVariables($0, variables: variables) }
        guard let node = selectAXNode(nodes, oid: step.axOID, label: label) else {
            throw RuntimeError("AX node not found for replay tap step")
        }
        return tapRequest(for: node, width: step.width, height: step.height, duration: step.duration)
    }
    return TKInputRequest.tap(
        x: step.x,
        y: step.y,
        targetOID: step.oid,
        width: step.width,
        height: step.height,
        duration: step.duration
    )
}

func replayTextInputRequest(
    _ step: TKReplayPlanStep,
    variables: [String: String]
) throws -> (request: TKInputRequest, redactedValue: String?) {
    try validateReplayXYPair(step)
    switch step.action {
    case .paste:
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay paste step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        return (
            TKInputRequest.paste(value, targetOID: step.oid, x: step.x, y: step.y, secure: step.secure ?? false),
            step.redactedValue(substitutedValue: value)
        )
    case .type:
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay type step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        return (
            TKInputRequest(type: .typeText, targetOID: step.oid, text: value, secure: step.secure),
            step.redactedValue(substitutedValue: value)
        )
    case .clear:
        return (TKInputRequest.clear(targetOID: step.oid, x: step.x, y: step.y), nil)
    default:
        throw RuntimeError("Replay text input builder received unsupported action: \(step.action.rawValue)")
    }
}

func replayWaitRequest(_ step: TKReplayPlanStep, variables: [String: String]) throws -> WaitRequest {
    let conditionCount = [
        step.text != nil,
        step.gone != nil,
        step.exists != nil,
        step.idle == true,
        step.hierarchyChange == true,
        step.predicate != nil,
    ].filter { $0 }.count
    guard conditionCount == 1 else {
        throw RuntimeError("Replay wait step requires exactly one condition: text, gone, exists, idle, hierarchyChange, or predicate")
    }
    guard let condition = step.waitCondition else {
        throw RuntimeError("Replay wait step requires one condition: text, gone, exists, idle, hierarchyChange, or predicate")
    }
    switch condition {
    case .text:
        return WaitRequest(
            condition: .text,
            query: try step.text.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .gone:
        return WaitRequest(
            condition: .gone,
            query: try step.gone.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .exists:
        return WaitRequest(
            condition: .exists,
            query: try step.exists.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .idle:
        return WaitRequest(condition: .idle, query: nil, predicate: nil, role: nil, timeout: step.timeout ?? 10, interval: step.interval ?? 0.5)
    case .hierarchyChange:
        return WaitRequest(condition: .hierarchyChange, query: nil, predicate: nil, role: nil, timeout: step.timeout ?? 10, interval: step.interval ?? 0.5)
    case .predicate:
        return WaitRequest(
            condition: .predicate,
            query: nil,
            predicate: try step.predicate.map { try TKReplaySubstituteVariables($0, variables: variables) },
            role: nil,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    }
}

func replayCommand(
    for step: TKReplayPlanStep,
    plan: TKReplayPlan,
    index: Int,
    variables: [String: String]
) throws -> [String] {
    try TKReplayStepExecution.argv(for: step, planName: plan.name, index: index, variables: variables)
}

func validateReplayXYPair(_ step: TKReplayPlanStep) throws {
    if (step.x == nil) != (step.y == nil) {
        throw RuntimeError("Replay \(step.action.rawValue) step requires x and y together")
    }
}

func replayOutputPath(_ raw: String?, fallback: String, variables: [String: String]) throws -> String {
    try TKReplaySubstituteVariables(raw ?? fallback, variables: variables)
}

func replayArtifactName(plan: TKReplayPlan, step: TKReplayPlanStep, index: Int) -> String {
    TKReplayStepExecution.artifactName(planName: plan.name, step: step, index: index)
}

func sanitizedPathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    let scalars = value.unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
    return collapsed.isEmpty ? "triton-replay" : collapsed
}

func failReplayValidation(_ message: String, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Run `triton schema --command replay --json` to inspect required fields"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}
