import Foundation
import Yams

let tritonTestSupportedSteps = ["launch", "takeScreenshot", "tap", "assertVisible"]

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
            message: "Only .tritontest.yaml version 1 is supported in P0B.",
            path: "$.version",
            allowed: ["1"]
        )
    }

    let name = try requiredNonEmptyString(root["name"], path: "$.name")
    let app = try parseTestApp(root["app"])
    let device = try parseTestDevice(root["device"])
    let settings = try parseTestSettings(root["settings"])
    let steps = try parseTestSteps(root["steps"], defaultTimeoutMs: settings.timeoutMs)

    return TKTestNormalizedPlan(
        name: name,
        app: app,
        device: device,
        settings: settings,
        steps: steps
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
            message: "\(stepType) is not supported by the P0B validate-only contract.",
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

    let optional = try parseStepOptional(step["optional"], path: "\(path).optional")
    let timeoutMs = try parseStepTimeout(step["timeoutMs"], path: "\(path).timeoutMs")

    switch stepType {
    case "launch":
        _ = try mappingPayload(step[stepType], path: "\(path).launch")
        return TKTestPlanStep(index: index, id: id, kind: "action", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil)
    case "takeScreenshot":
        _ = try mappingPayload(step[stepType], path: "\(path).takeScreenshot")
        return TKTestPlanStep(index: index, id: id, kind: "observation", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: nil)
    case "tap":
        let point = try parseTapPayload(step[stepType], path: "\(path).tap")
        return TKTestPlanStep(index: index, id: id, kind: "action", type: stepType, optional: optional, timeoutMs: timeoutMs, point: point, selector: nil)
    case "assertVisible":
        let selector = try parseAssertVisiblePayload(step[stepType], path: "\(path).assertVisible")
        return TKTestPlanStep(index: index, id: id, kind: "assertion", type: stepType, optional: optional, timeoutMs: timeoutMs, point: nil, selector: selector)
    default:
        throw testValidationFailure(
            code: "unsupported_step",
            message: "\(stepType) is not supported by the P0B validate-only contract.",
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

private func parseStepOptional(_ value: Any?, path: String) throws -> Bool {
    guard let value else { return false }
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

private func parseTapPayload(_ value: Any?, path: String) throws -> TKTestPlanPoint {
    let payload = try mappingPayload(value, path: path)
    guard let rawPoint = payload["point"] else {
        if let unsupported = payload.keys.sorted().first {
            throw testValidationFailure(
                code: "unsupported_selector",
                message: "tap only supports point selectors in P0B.",
                path: "\(path).\(unsupported)"
            )
        }
        throw testValidationFailure(
            code: "missing_required_field",
            message: "tap.point is required.",
            path: "\(path).point"
        )
    }
    guard let point = rawPoint as? [String: Any] else {
        throw testValidationFailure(
            code: "invalid_point",
            message: "tap.point must be a mapping with x, y, and coordinateSpace.",
            path: "\(path).point"
        )
    }

    let x = try requiredNonNegativeDouble(point["x"], path: "\(path).point.x")
    let y = try requiredNonNegativeDouble(point["y"], path: "\(path).point.y")
    let coordinateSpace = point["coordinateSpace"] as? String
    guard coordinateSpace == "runtime-point" else {
        throw testValidationFailure(
            code: "unsupported_coordinate_space",
            message: "tap.point.coordinateSpace must be runtime-point.",
            path: "\(path).point.coordinateSpace",
            allowed: ["runtime-point"]
        )
    }
    return TKTestPlanPoint(x: x, y: y, coordinateSpace: "runtime-point")
}

private func parseAssertVisiblePayload(_ value: Any?, path: String) throws -> TKTestPlanSelector {
    let payload = try mappingPayload(value, path: path)
    guard let rawText = payload["text"] else {
        if let unsupported = payload.keys.sorted().first {
            throw testValidationFailure(
                code: "unsupported_selector",
                message: "assertVisible only supports text selectors in P0B.",
                path: "\(path).\(unsupported)"
            )
        }
        throw testValidationFailure(
            code: "missing_required_field",
            message: "assertVisible.text is required.",
            path: "\(path).text"
        )
    }
    let text = try requiredNonEmptyString(rawText, path: "\(path).text")
    return TKTestPlanSelector(text: text, match: "exact", source: "ax")
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
