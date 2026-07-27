import Foundation
import Yams

let tritonTestSupportedSteps = [
    "launch",
    "stop",
    "takeScreenshot",
    "tap",
    "input",
    "press",
    "swipe",
    "assertVisible",
    "assertNotVisible",
    "scrollUntilVisible",
    "assertWithAI",
    "assertNoDefectsWithAI",
    "extractTextWithAI",
    "assertScreenshot",
]

func validateTritonTestContract(yaml: String, inputPath: String) throws -> TKTestNormalizedPlan {
    let parsed: Any?
    do {
        parsed = try Yams.load(yaml: yaml)
    } catch {
        throw testValidationFailure(
            code: "invalid_yaml",
            message: "The .tritontest.yaml file is not valid YAML.",
            path: "$"
        )
    }

    guard let root = parsed as? [String: Any] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "Root YAML document must be a mapping.",
            path: "$"
        )
    }

    let version = try requiredInt(root["version"], path: "$.version")
    guard version == 1 else {
        throw testValidationFailure(
            code: "unsupported_schema_version",
            message: "Only .tritontest.yaml version 1 is supported.",
            path: "$.version",
            allowed: ["1"]
        )
    }

    let name = try requiredNonEmptyString(root["name"], path: "$.name")
    let app = try parseTestApp(root["app"])
    let device = try parseTestDevice(root["device"])
    let settings = try parseTestSettings(root["settings"])
    let provenance = try parseTestProvenance(root["provenance"])
    let steps = try parseTestSteps(root["steps"], defaultTimeoutMs: settings.timeoutMs)

    return TKTestNormalizedPlan(
        name: name,
        app: app,
        device: device,
        settings: settings,
        steps: steps,
        provenance: provenance
    )
}

private func parseTestProvenance(_ value: Any?) throws -> TKTestPlanProvenance? {
    guard let value else {
        return nil
    }
    guard let provenance = value as? [String: Any] else {
        throw testValidationFailure(
            code: "invalid_optional_type",
            message: "provenance must be a mapping when provided.",
            path: "$.provenance"
        )
    }

    let importerVersion = try requiredInt(provenance["importerVersion"], path: "$.provenance.importerVersion")
    guard importerVersion == 1 else {
        throw testValidationFailure(
            code: "unsupported_schema_version",
            message: "Only provenance importerVersion 1 is supported.",
            path: "$.provenance.importerVersion",
            allowed: ["1"]
        )
    }
    let sourceKind = try requiredNonEmptyString(provenance["sourceKind"], path: "$.provenance.sourceKind")
    guard sourceKind == "triton.testrec.compiled-contract" else {
        throw testValidationFailure(
            code: "unsupported_provenance",
            message: "provenance.sourceKind must be triton.testrec.compiled-contract.",
            path: "$.provenance.sourceKind",
            allowed: ["triton.testrec.compiled-contract"]
        )
    }
    let sourcePlatform = try requiredNonEmptyString(provenance["sourcePlatform"], path: "$.provenance.sourcePlatform")

    guard let rawContractRef = provenance["contractRef"] as? [String: Any] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "provenance.contractRef is required.",
            path: "$.provenance.contractRef"
        )
    }
    let path = try requiredNonEmptyString(rawContractRef["path"], path: "$.provenance.contractRef.path")
    guard path == "compiled-contract.json" else {
        throw testValidationFailure(
            code: "invalid_provenance",
            message: "provenance.contractRef.path must be the package-relative compiled-contract.json artifact.",
            path: "$.provenance.contractRef.path"
        )
    }
    let byteCount = try requiredInt(rawContractRef["byteCount"], path: "$.provenance.contractRef.byteCount")
    guard byteCount > 0 else {
        throw testValidationFailure(
            code: "invalid_provenance",
            message: "provenance.contractRef.byteCount must be positive.",
            path: "$.provenance.contractRef.byteCount"
        )
    }
    let digestAlgorithm = try requiredNonEmptyString(rawContractRef["digestAlgorithm"], path: "$.provenance.contractRef.digestAlgorithm")
    guard digestAlgorithm == "fnv1a64" else {
        throw testValidationFailure(
            code: "invalid_provenance",
            message: "provenance.contractRef.digestAlgorithm must be fnv1a64.",
            path: "$.provenance.contractRef.digestAlgorithm"
        )
    }
    let digest = try requiredNonEmptyString(rawContractRef["digest"], path: "$.provenance.contractRef.digest")
    guard digest.range(of: #"^[0-9a-f]{16}$"#, options: .regularExpression) != nil else {
        throw testValidationFailure(
            code: "invalid_provenance",
            message: "provenance.contractRef.digest must be a lowercase 16-character fnv1a64 digest.",
            path: "$.provenance.contractRef.digest"
        )
    }

    return TKTestPlanProvenance(
        importerVersion: importerVersion,
        sourceKind: sourceKind,
        sourcePlatform: sourcePlatform,
        contractRef: TKTestRecorderReplayContractRef(
            path: path,
            byteCount: byteCount,
            digestAlgorithm: digestAlgorithm,
            digest: digest
        )
    )
}

func testValidationFailureResponse(_ failure: TKTestValidationFailure) -> TKTestValidationFailureResponse {
    TKTestValidationFailureResponse(error: failure.detail)
}

func testValidationFailure(
    code: String,
    message: String,
    path: String,
    allowed: [String]? = nil
) -> TKTestValidationFailure {
    TKTestValidationFailure(detail: TKTestValidationErrorDetail(
        type: "validation_error",
        message: message,
        path: path,
        code: code,
        allowed: allowed
    ))
}

private func parseTestApp(_ value: Any?) throws -> TKTestPlanApp {
    guard let app = value as? [String: Any] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "app.bundleId is required.",
            path: "$.app.bundleId"
        )
    }
    let bundleID = try requiredNonEmptyString(app["bundleId"], path: "$.app.bundleId")
    guard isValidBundleIdentifier(bundleID) else {
        throw testValidationFailure(
            code: "invalid_app_bundle_id",
            message: "app.bundleId must be a valid reverse-DNS bundle identifier.",
            path: "$.app.bundleId"
        )
    }
    return TKTestPlanApp(bundleId: bundleID)
}

private func parseTestDevice(_ value: Any?) throws -> TKTestPlanDevice {
    guard let device = value as? [String: Any] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "device.platform is required.",
            path: "$.device.platform"
        )
    }
    let platform = try requiredNonEmptyString(device["platform"], path: "$.device.platform")
    return TKTestPlanDevice(platform: platform)
}

private func parseTestSettings(_ value: Any?) throws -> TKTestPlanSettings {
    guard let value else {
        return TKTestPlanSettings(strict: true, timeoutMs: 5_000, retry: TKTestPlanRetry(count: 0, intervalMs: 250))
    }
    guard let settings = value as? [String: Any] else {
        throw testValidationFailure(
            code: "invalid_optional_type",
            message: "settings must be a mapping when provided.",
            path: "$.settings"
        )
    }

    let strict: Bool
    if let rawStrict = settings["strict"] {
        guard let parsedStrict = rawStrict as? Bool else {
            throw testValidationFailure(
                code: "invalid_optional_type",
                message: "settings.strict must be a boolean.",
                path: "$.settings.strict"
            )
        }
        strict = parsedStrict
    } else {
        strict = true
    }

    let timeoutMs = try optionalPositiveInt(settings["timeoutMs"], path: "$.settings.timeoutMs", defaultValue: 5_000)
    let retry = try parseTestRetry(settings["retry"])
    return TKTestPlanSettings(strict: strict, timeoutMs: timeoutMs, retry: retry)
}

private func parseTestRetry(_ value: Any?) throws -> TKTestPlanRetry {
    guard let value else {
        return TKTestPlanRetry(count: 0, intervalMs: 250)
    }
    guard let retry = value as? [String: Any] else {
        throw testValidationFailure(
            code: "invalid_optional_type",
            message: "settings.retry must be a mapping when provided.",
            path: "$.settings.retry"
        )
    }
    let count = try optionalNonNegativeInt(retry["count"], path: "$.settings.retry.count", defaultValue: 0)
    let intervalMs = try optionalPositiveInt(retry["intervalMs"], path: "$.settings.retry.intervalMs", defaultValue: 250)
    return TKTestPlanRetry(count: count, intervalMs: intervalMs)
}

private func parseTestSteps(_ value: Any?, defaultTimeoutMs: Int) throws -> [TKTestPlanStep] {
    guard let rawSteps = value as? [Any], !rawSteps.isEmpty else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "steps must contain at least one step.",
            path: "$.steps"
        )
    }

    var ids = Set<String>()
    return try rawSteps.enumerated().map { index, rawStep in
        guard let step = rawStep as? [String: Any] else {
            throw testValidationFailure(
                code: "unknown_step",
                message: "Each step must be a mapping with one supported step key.",
                path: "$.steps[\(index)]",
                allowed: tritonTestSupportedSteps
            )
        }
        return try parseTestStep(step, index: index, defaultTimeoutMs: defaultTimeoutMs, ids: &ids)
    }
}

private func parseTestStep(
    _ step: [String: Any],
    index: Int,
    defaultTimeoutMs: Int,
    ids: inout Set<String>
) throws -> TKTestPlanStep {
    let path = "$.steps[\(index)]"
    let stepKeys = step.keys
        .filter { !["id", "optional", "timeoutMs"].contains($0) }
        .sorted()

    guard let stepType = stepKeys.first else {
        throw testValidationFailure(
            code: "unknown_step",
            message: "Step must contain one of the supported step keys.",
            path: path,
            allowed: tritonTestSupportedSteps
        )
    }
    guard stepKeys.count == 1 else {
        throw testValidationFailure(
            code: "unknown_step",
            message: "Step must contain exactly one supported step key.",
            path: path,
            allowed: tritonTestSupportedSteps
        )
    }
    guard tritonTestSupportedSteps.contains(stepType) else {
        throw testValidationFailure(
            code: "unsupported_step",
            message: "\(stepType) is not supported by the test contract.",
            path: "\(path).\(stepType)",
            allowed: tritonTestSupportedSteps
        )
    }

    let id = try parseStepID(step["id"], index: index, path: "\(path).id")
    guard ids.insert(id).inserted else {
        throw testValidationFailure(
            code: "duplicate_step_id",
            message: "Step id must be unique after implicit ids are assigned.",
            path: "\(path).id"
        )
    }

    let optional = try parseStepOptional(step["optional"], path: "\(path).optional", defaultValue: defaultOptional(for: stepType))
    let timeoutMs = try parseStepTimeout(step["timeoutMs"], path: "\(path).timeoutMs")

    switch stepType {
    case "launch":
        _ = try mappingPayload(step[stepType], path: "\(path).launch")
        return TKTestPlanStep(index: index, id: id, kind: "action", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil)
    case "stop":
        _ = try mappingPayload(step[stepType], path: "\(path).stop")
        return TKTestPlanStep(index: index, id: id, kind: "action", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil)
    case "takeScreenshot":
        _ = try mappingPayload(step[stepType], path: "\(path).takeScreenshot")
        return TKTestPlanStep(index: index, id: id, kind: "observation", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil)
    case "tap":
        let payload = try parseTapPayload(step[stepType], path: "\(path).tap")
        return TKTestPlanStep(
            index: index,
            id: id,
            kind: "action",
            type: stepType,
            optional: optional,
            timeoutMs: timeoutMs,
            point: payload.point,
            selector: payload.selector,
            target: payload.target,
            grounding: payload.grounding,
            provider: payload.provider,
            model: payload.model,
            modelPath: payload.modelPath,
            maxTokens: payload.maxTokens,
            temperature: payload.temperature,
            seed: payload.seed,
            promptTemplate: payload.promptTemplate,
            allowModelDownload: payload.allowModelDownload
        )
    case "input":
        let text = try parseInputPayload(step[stepType], path: "\(path).input")
        return TKTestPlanStep(index: index, id: id, kind: "action", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil, text: text)
    case "press":
        let button = try parsePressPayload(step[stepType], path: "\(path).press")
        return TKTestPlanStep(index: index, id: id, kind: "action", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil, button: button)
    case "swipe":
        let points = try parseSwipePayload(step[stepType], path: "\(path).swipe")
        return TKTestPlanStep(index: index, id: id, kind: "action", type: stepType, optional: optional, timeoutMs: timeoutMs, point: points.from, endPoint: points.to, selector: nil)
    case "assertVisible":
        let selector = try parseAssertVisiblePayload(step[stepType], path: "\(path).assertVisible")
        return TKTestPlanStep(index: index, id: id, kind: "assertion", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: selector)
    case "assertNotVisible":
        let selector = try parseTextAssertionPayload(step[stepType], path: "\(path).assertNotVisible", stepType: "assertNotVisible")
        return TKTestPlanStep(index: index, id: id, kind: "assertion", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: selector)
    case "scrollUntilVisible":
        let payload = try parseScrollUntilVisiblePayload(step[stepType], path: "\(path).scrollUntilVisible")
        return TKTestPlanStep(
            index: index,
            id: id,
            kind: "action",
            type: stepType,
            optional: optional,
            timeoutMs: timeoutMs,
            point: nil,
            selector: payload.selector,
            direction: payload.direction,
            maxScrolls: payload.maxScrolls
        )
    case "assertWithAI":
        let payload = try parseAIStepPayload(step[stepType], path: "\(path).assertWithAI", requiresPrompt: true)
        return TKTestPlanStep(index: index, id: id, kind: "assertion", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil, provider: payload.provider, prompt: payload.prompt)
    case "assertNoDefectsWithAI":
        let payload = try parseAIStepPayload(step[stepType], path: "\(path).assertNoDefectsWithAI", requiresPrompt: false)
        return TKTestPlanStep(index: index, id: id, kind: "assertion", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil, provider: payload.provider, prompt: payload.prompt)
    case "extractTextWithAI":
        let payload = try parseAIStepPayload(step[stepType], path: "\(path).extractTextWithAI", requiresPrompt: false)
        return TKTestPlanStep(index: index, id: id, kind: "observation", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil, provider: payload.provider, prompt: payload.prompt)
    case "assertScreenshot":
        let payload = try parseAssertScreenshotPayload(step[stepType], path: "\(path).assertScreenshot")
        return TKTestPlanStep(index: index, id: id, kind: "assertion", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil, baseline: payload.baseline, threshold: payload.threshold, cropOn: payload.cropOn)
    default:
        throw testValidationFailure(
            code: "unsupported_step",
            message: "\(stepType) is not supported by the test contract.",
            path: "\(path).\(stepType)",
            allowed: tritonTestSupportedSteps
        )
    }
}

private func parseStepID(_ value: Any?, index: Int, path: String) throws -> String {
    guard let value else {
        return String(format: "step-%03d", index)
    }
    return try requiredNonEmptyString(value, path: path)
}

private func defaultOptional(for stepType: String) -> Bool {
    ["assertWithAI", "assertNoDefectsWithAI", "extractTextWithAI"].contains(stepType)
}

private func parseStepOptional(_ value: Any?, path: String, defaultValue: Bool) throws -> Bool {
    guard let value else { return defaultValue }
    guard let optional = value as? Bool else {
        throw testValidationFailure(
            code: "invalid_optional_type",
            message: "step.optional must be a boolean.",
            path: path
        )
    }
    return optional
}

private func parseStepTimeout(_ value: Any?, path: String) throws -> Int? {
    guard let value else { return nil }
    return try positiveInt(value, path: path)
}

private func parseAIStepPayload(_ value: Any?, path: String, requiresPrompt: Bool) throws -> (provider: String, prompt: String?) {
    let payload = try mappingPayload(value, path: path)
    let prompt: String?
    if let rawPrompt = payload["prompt"] {
        prompt = try requiredNonEmptyString(rawPrompt, path: "\(path).prompt")
    } else if requiresPrompt {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "\(path).prompt is required.",
            path: "\(path).prompt"
        )
    } else {
        prompt = nil
    }
    let provider = try parseAIProvider(payload["provider"], path: "\(path).provider")
    return (provider, prompt)
}

private func parseAssertScreenshotPayload(_ value: Any?, path: String) throws -> (baseline: String, threshold: Double, cropOn: String?) {
    let payload = try mappingPayload(value, path: path)
    let baseline = try requiredNonEmptyString(payload["baseline"], path: "\(path).baseline")
    let threshold = try optionalThreshold(payload["threshold"], path: "\(path).threshold", defaultValue: 0.0)
    let cropOn = try optionalNonEmptyString(payload["cropOn"], path: "\(path).cropOn")
    return (baseline, threshold, cropOn)
}

private func parseAIProvider(_ value: Any?, path: String) throws -> String {
    guard let value else { return "mock" }
    let provider = try requiredNonEmptyString(value, path: path)
    guard provider == "mock" else {
        throw testValidationFailure(
            code: "ai_unsupported_provider",
            message: "P14 AI test steps only support provider=mock.",
            path: path,
            allowed: ["mock"]
        )
    }
    return provider
}

private func parseTapPayload(_ value: Any?, path: String) throws -> (
    point: TKTestPlanPoint?,
    selector: TKTestPlanSelector?,
    target: String?,
    grounding: String?,
    provider: String?,
    model: String?,
    modelPath: String?,
    maxTokens: Int?,
    temperature: Double?,
    seed: Int?,
    promptTemplate: String?,
    allowModelDownload: Bool?
) {
    let payload = try mappingPayload(value, path: path)
    if let rawPoint = payload["point"] {
        if payload["text"] != nil || payload["target"] != nil || payload["grounding"] != nil || payload["provider"] != nil || payload["model"] != nil || payload["modelPath"] != nil {
            throw testValidationFailure(
                code: "unsupported_selector",
                message: "tap.point cannot be combined with text selector or VLM target grounding.",
                path: path
            )
        }
        let point = try parseRuntimePoint(rawPoint, path: "\(path).point", fieldName: "tap.point")
        return (point, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    if payload["text"] != nil {
        if payload["target"] != nil || payload["grounding"] != nil || payload["provider"] != nil || payload["model"] != nil || payload["modelPath"] != nil {
            throw testValidationFailure(
                code: "unsupported_selector",
                message: "tap.text cannot be combined with VLM target grounding.",
                path: path
            )
        }
        let selector = try parseTextAssertionPayload(value, path: path, stepType: "tap")
        return (nil, selector, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    if let rawTarget = payload["target"] {
        let target = try requiredNonEmptyString(rawTarget, path: "\(path).target")
        let grounding = try requiredNonEmptyString(payload["grounding"], path: "\(path).grounding")
        guard grounding == "vlm" else {
            throw testValidationFailure(
                code: "unsupported_grounding",
                message: "tap.target only supports grounding=vlm.",
                path: "\(path).grounding",
                allowed: ["vlm"]
            )
        }
        let provider = try requiredNonEmptyString(payload["provider"], path: "\(path).provider")
        guard ["mock", "openai-compatible", "mlx-swift-lm"].contains(provider) else {
            throw testValidationFailure(
                code: "vlm_unsupported_provider",
                message: "Unsupported VLM provider \(provider).",
                path: "\(path).provider",
                allowed: ["mock", "openai-compatible", "mlx-swift-lm"]
            )
        }
        let model = try optionalNonEmptyString(payload["model"], path: "\(path).model")
        let modelPath = try optionalNonEmptyString(payload["modelPath"], path: "\(path).modelPath")
        let maxTokens = try optionalPositiveInt(payload["maxTokens"], path: "\(path).maxTokens", defaultValue: 64)
        let temperature = try optionalDouble(payload["temperature"], path: "\(path).temperature")
        let seed = try optionalNonNegativeInt(payload["seed"], path: "\(path).seed", defaultValue: 0)
        let promptTemplate = try optionalNonEmptyString(payload["promptTemplate"], path: "\(path).promptTemplate")
        let allowModelDownload = try optionalBool(payload["allowModelDownload"], path: "\(path).allowModelDownload")
        return (nil, nil, target, grounding, provider, model, modelPath, maxTokens, temperature, seed, promptTemplate, allowModelDownload)
    }
    if let unsupported = payload.keys.sorted().first {
        throw testValidationFailure(
            code: "unsupported_selector",
            message: "tap only supports point selectors, exact AX text selectors, or explicit VLM target grounding.",
            path: "\(path).\(unsupported)"
        )
    }
    throw testValidationFailure(
        code: "missing_required_field",
        message: "tap.point, tap.text, or tap.target is required.",
        path: "\(path).point"
    )
}

private func parseSwipePayload(_ value: Any?, path: String) throws -> (from: TKTestPlanPoint, to: TKTestPlanPoint) {
    let payload = try mappingPayload(value, path: path)
    guard let rawFrom = payload["from"] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "swipe.from is required.",
            path: "\(path).from"
        )
    }
    guard let rawTo = payload["to"] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "swipe.to is required.",
            path: "\(path).to"
        )
    }
    let from = try parseRuntimePoint(rawFrom, path: "\(path).from", fieldName: "swipe.from")
    let to = try parseRuntimePoint(rawTo, path: "\(path).to", fieldName: "swipe.to")
    return (from, to)
}

private func parseRuntimePoint(_ value: Any?, path: String, fieldName: String) throws -> TKTestPlanPoint {
    guard let point = value as? [String: Any] else {
        throw testValidationFailure(
            code: "invalid_point",
            message: "\(fieldName) must be a mapping with x, y, and coordinateSpace.",
            path: path
        )
    }

    let x = try requiredNonNegativeDouble(point["x"], path: "\(path).x")
    let y = try requiredNonNegativeDouble(point["y"], path: "\(path).y")
    let coordinateSpace = point["coordinateSpace"] as? String
    guard coordinateSpace == "runtime-point" else {
        throw testValidationFailure(
            code: "unsupported_coordinate_space",
            message: "\(fieldName).coordinateSpace must be runtime-point.",
            path: "\(path).coordinateSpace",
            allowed: ["runtime-point"]
        )
    }
    return TKTestPlanPoint(x: x, y: y, coordinateSpace: "runtime-point")
}

private func parseAssertVisiblePayload(_ value: Any?, path: String) throws -> TKTestPlanSelector {
    try parseTextAssertionPayload(value, path: path, stepType: "assertVisible")
}

private func parseTextAssertionPayload(_ value: Any?, path: String, stepType: String) throws -> TKTestPlanSelector {
    let payload = try mappingPayload(value, path: path)
    guard let rawText = payload["text"] else {
        if let unsupported = payload.keys.sorted().first {
            throw testValidationFailure(
                code: "unsupported_selector",
                message: "\(stepType) only supports text selectors.",
                path: "\(path).\(unsupported)"
            )
        }
        throw testValidationFailure(
            code: "missing_required_field",
            message: "\(stepType).text is required.",
            path: "\(path).text"
        )
    }
    let text = try requiredNonEmptyString(rawText, path: "\(path).text")
    let match = try parseSelectorMatch(payload["match"], path: "\(path).match")
    let source = try parseSelectorSource(payload["source"], path: "\(path).source")
    return TKTestPlanSelector(text: text, match: match, source: source)
}

private func parseInputPayload(_ value: Any?, path: String) throws -> String {
    let payload = try mappingPayload(value, path: path)
    guard let rawText = payload["text"] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "input.text is required.",
            path: "\(path).text"
        )
    }
    return try requiredNonEmptyString(rawText, path: "\(path).text")
}

private func parsePressPayload(_ value: Any?, path: String) throws -> String {
    let payload = try mappingPayload(value, path: path)
    let rawButton = payload["button"] ?? payload["key"]
    guard let rawButton else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "press.button is required.",
            path: "\(path).button"
        )
    }
    return try requiredNonEmptyString(rawButton, path: "\(path).button")
}

private func parseScrollUntilVisiblePayload(_ value: Any?, path: String) throws -> (selector: TKTestPlanSelector, direction: String, maxScrolls: Int) {
    let payload = try mappingPayload(value, path: path)
    let selector = try parseTextAssertionPayload(value, path: path, stepType: "scrollUntilVisible")
    let direction: String
    if let rawDirection = payload["direction"] {
        direction = try requiredNonEmptyString(rawDirection, path: "\(path).direction")
    } else {
        direction = "down"
    }
    guard ["down", "up", "left", "right"].contains(direction) else {
        throw testValidationFailure(
            code: "unsupported_direction",
            message: "scrollUntilVisible.direction must be down, up, left, or right.",
            path: "\(path).direction",
            allowed: ["down", "up", "left", "right"]
        )
    }
    let maxScrolls = try optionalPositiveInt(payload["maxScrolls"], path: "\(path).maxScrolls", defaultValue: 5)
    return (selector, direction, maxScrolls)
}

private func parseSelectorMatch(_ value: Any?, path: String) throws -> String {
    guard let value else { return "exact" }
    let match = try requiredNonEmptyString(value, path: path)
    guard match == "exact" else {
        throw testValidationFailure(
            code: "unsupported_selector",
            message: "Only exact text match is supported.",
            path: path,
            allowed: ["exact"]
        )
    }
    return match
}

private func parseSelectorSource(_ value: Any?, path: String) throws -> String {
    guard let value else { return "ax" }
    let source = try requiredNonEmptyString(value, path: path)
    guard source == "ax" else {
        throw testValidationFailure(
            code: "unsupported_selector",
            message: "Only ax text observation source is supported.",
            path: path,
            allowed: ["ax"]
        )
    }
    return source
}

private func mappingPayload(_ value: Any?, path: String) throws -> [String: Any] {
    guard let value else { return [:] }
    if value is NSNull {
        return [:]
    }
    guard let mapping = value as? [String: Any] else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "\(path) must be a mapping.",
            path: path
        )
    }
    return mapping
}

private func requiredNonEmptyString(_ value: Any?, path: String) throws -> String {
    guard let string = value as? String,
          !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "\(path) is required.",
            path: path
        )
    }
    return string
}

private func requiredInt(_ value: Any?, path: String) throws -> Int {
    guard let value else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "\(path) is required.",
            path: path
        )
    }
    return try integer(value, path: path)
}

private func optionalPositiveInt(_ value: Any?, path: String, defaultValue: Int) throws -> Int {
    guard let value else { return defaultValue }
    return try positiveInt(value, path: path)
}

private func optionalNonEmptyString(_ value: Any?, path: String) throws -> String? {
    guard let value else { return nil }
    return try requiredNonEmptyString(value, path: path)
}

private func optionalThreshold(_ value: Any?, path: String, defaultValue: Double) throws -> Double {
    guard let value else { return defaultValue }
    let parsed: Double
    if let double = value as? Double {
        parsed = double
    } else if let int = value as? Int {
        parsed = Double(int)
    } else {
        throw testValidationFailure(
            code: "invalid_threshold",
            message: "\(path) must be a number between 0 and 1.",
            path: path
        )
    }
    guard parsed.isFinite, parsed >= 0, parsed <= 1 else {
        throw testValidationFailure(
            code: "invalid_threshold",
            message: "\(path) must be between 0 and 1.",
            path: path
        )
    }
    return parsed
}

private func optionalDouble(_ value: Any?, path: String) throws -> Double? {
    guard let value else { return nil }
    if let double = value as? Double {
        guard double.isFinite else {
            throw testValidationFailure(code: "invalid_optional_type", message: "\(path) must be finite.", path: path)
        }
        return double
    }
    if let int = value as? Int {
        return Double(int)
    }
    throw testValidationFailure(
        code: "invalid_optional_type",
        message: "\(path) must be a number.",
        path: path
    )
}

private func optionalBool(_ value: Any?, path: String) throws -> Bool? {
    guard let value else { return nil }
    guard let bool = value as? Bool else {
        throw testValidationFailure(
            code: "invalid_optional_type",
            message: "\(path) must be a boolean.",
            path: path
        )
    }
    return bool
}

private func optionalNonNegativeInt(_ value: Any?, path: String, defaultValue: Int) throws -> Int {
    guard let value else { return defaultValue }
    let parsed = try integer(value, path: path)
    guard parsed >= 0 else {
        throw testValidationFailure(
            code: "invalid_timeout",
            message: "\(path) must be non-negative.",
            path: path
        )
    }
    return parsed
}

private func positiveInt(_ value: Any, path: String) throws -> Int {
    let parsed = try integer(value, path: path)
    guard parsed > 0 else {
        throw testValidationFailure(
            code: "invalid_timeout",
            message: "\(path) must be greater than zero.",
            path: path
        )
    }
    return parsed
}

private func integer(_ value: Any, path: String) throws -> Int {
    if let int = value as? Int {
        return int
    }
    if let double = value as? Double, double.rounded(.towardZero) == double {
        return Int(double)
    }
    throw testValidationFailure(
        code: "invalid_timeout",
        message: "\(path) must be an integer.",
        path: path
    )
}

private func requiredNonNegativeDouble(_ value: Any?, path: String) throws -> Double {
    guard let value else {
        throw testValidationFailure(
            code: "invalid_point",
            message: "\(path) is required.",
            path: path
        )
    }
    let parsed: Double
    if let double = value as? Double {
        parsed = double
    } else if let int = value as? Int {
        parsed = Double(int)
    } else {
        throw testValidationFailure(
            code: "invalid_point",
            message: "\(path) must be a number.",
            path: path
        )
    }
    guard parsed.isFinite, parsed >= 0 else {
        throw testValidationFailure(
            code: "invalid_point",
            message: "\(path) must be a non-negative finite number.",
            path: path
        )
    }
    return parsed
}

private func isValidBundleIdentifier(_ value: String) -> Bool {
    value.range(
        of: #"^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$"#,
        options: .regularExpression
    ) != nil
}
